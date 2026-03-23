module Api
  module V1
    class WhatsappWebhookController < BaseController
      skip_before_action :verify_authenticity_token, raise: false

      # WhatsApp Cloud API verification (GET)
      def verify
        mode = params["hub.mode"]
        token = params["hub.verify_token"]
        challenge = params["hub.challenge"]

        if mode == "subscribe" && token.present? &&
           ActiveSupport::SecurityUtils.secure_compare(token, whatsapp_verify_token)
          render plain: challenge, status: :ok
        else
          render plain: "Forbidden", status: :forbidden
        end
      end

      # WhatsApp Cloud API incoming messages (POST)
      def receive
        payload = params.permit!.to_h
        entry = payload.dig("entry", 0)
        return render_success unless entry

        changes = entry.dig("changes", 0)
        return render_success unless changes

        value = changes["value"]
        return render_success unless value

        messages = value["messages"]
        return render_success unless messages&.any?

        message = messages.first
        from = message["from"]
        contact_name = value.dig("contacts", 0, "profile", "name") || "User"
        phone_number_id = value.dig("metadata", "phone_number_id")
        bot_service = MessagingBotService.new(platform: :whatsapp)

        # Handle image messages (screenshots for conflict mediator)
        if message["type"] == "image"
          image_id = message.dig("image", "id")
          caption = message.dig("image", "caption") || ""

          image_data = download_whatsapp_media(image_id)
          if image_data
            reply = bot_service.process_photo(
              platform_user_id: from,
              image_data: image_data,
              caption: caption,
              user_name: contact_name
            )
          else
            reply = "Sorry, I couldn't download that image. Please try again."
          end

          send_whatsapp_message(from, reply, phone_number_id)
          return render_success
        end

        # Handle document messages (screenshots or text files)
        if message["type"] == "document"
          doc = message["document"]
          mime = doc["mime_type"] || ""

          if mime.start_with?("image/")
            image_data = download_whatsapp_media(doc["id"])
            if image_data
              reply = bot_service.process_photo(
                platform_user_id: from,
                image_data: image_data,
                caption: doc["caption"] || doc["filename"] || "",
                user_name: contact_name
              )
            else
              reply = "Sorry, I couldn't download that file. Please try again."
            end
          elsif mime == "text/plain" || doc["filename"]&.end_with?(".txt")
            file_content = download_whatsapp_text_file(doc["id"])
            if file_content
              reply = bot_service.process_text_file(
                platform_user_id: from,
                text_content: file_content,
                filename: doc["filename"] || "file.txt",
                user_name: contact_name
              )
            else
              reply = "Sorry, I couldn't read that file. Please try again."
            end
          else
            reply = "I can process image files (JPG, PNG) and .txt files. Please send a supported file type."
          end

          send_whatsapp_message(from, reply, phone_number_id)
          return render_success
        end

        # Handle text messages
        return render_success unless message["type"] == "text"

        text = message.dig("text", "body")
        reply = bot_service.process_message(
          platform_user_id: from,
          text: text,
          user_name: contact_name
        )

        send_whatsapp_message(from, reply, phone_number_id)
        render_success
      rescue StandardError => e
        Rails.logger.error("WhatsApp webhook error: #{e.message}")
        render_success # Always return 200 to Meta
      end

      private

      def whatsapp_verify_token
        Rails.application.config.whatsapp_verify_token.to_s
      end

      def send_whatsapp_message(to, text, phone_number_id)
        token = Rails.application.config.whatsapp_access_token
        url = "https://graph.facebook.com/v22.0/#{phone_number_id}/messages"

        response = HTTParty.post(url,
          headers: {
            "Authorization" => "Bearer #{token}",
            "Content-Type" => "application/json"
          },
          body: {
            messaging_product: "whatsapp",
            to: to,
            type: "text",
            text: { body: text }
          }.to_json
        )

        result = JSON.parse(response.body)
        if result["error"]
          Rails.logger.error("WhatsApp API error: #{result['error']['message']}")
        else
          Rails.logger.info("WhatsApp message sent to #{to}")
        end
      rescue StandardError => e
        Rails.logger.error("WhatsApp send error: #{e.message}")
      end

      def download_whatsapp_media(media_id)
        token = Rails.application.config.whatsapp_access_token

        # Step 1: Get media URL
        media_info = HTTParty.get("https://graph.facebook.com/v22.0/#{media_id}",
          headers: { "Authorization" => "Bearer #{token}" }
        )
        result = JSON.parse(media_info.body)
        return nil if result["error"]

        media_url = result["url"]
        mime_type = result["mime_type"] || "image/jpeg"
        return nil unless media_url

        # Step 2: Download the media
        response = HTTParty.get(media_url,
          headers: { "Authorization" => "Bearer #{token}" }
        )
        return nil unless response.success?

        {
          base64: Base64.strict_encode64(response.body),
          mime_type: mime_type
        }
      rescue StandardError => e
        Rails.logger.error("WhatsApp media download error: #{e.message}")
        nil
      end

      def download_whatsapp_text_file(media_id)
        token = Rails.application.config.whatsapp_access_token

        media_info = HTTParty.get("https://graph.facebook.com/v22.0/#{media_id}",
          headers: { "Authorization" => "Bearer #{token}" }
        )
        result = JSON.parse(media_info.body)
        return nil if result["error"]

        media_url = result["url"]
        return nil unless media_url

        response = HTTParty.get(media_url,
          headers: { "Authorization" => "Bearer #{token}" }
        )
        return nil unless response.success?

        response.body.force_encoding("UTF-8")
      rescue StandardError => e
        Rails.logger.error("WhatsApp text file download error: #{e.message}")
        nil
      end
    end
  end
end
