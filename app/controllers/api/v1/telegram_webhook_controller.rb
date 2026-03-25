module Api
  module V1
    class TelegramWebhookController < BaseController
      skip_before_action :verify_authenticity_token, raise: false

      def receive
        unless valid_token?
          return render_error("Unauthorized", status: :unauthorized)
        end

        update = params.permit!.to_h

        # Handle inline keyboard button clicks
        if update["callback_query"].present?
          handle_callback_query(update["callback_query"])
          return render_success
        end

        message = update.dig("message")
        return render_success unless message

        chat_id = message.dig("chat", "id")
        user_name = [message.dig("from", "first_name"), message.dig("from", "last_name")].compact.join(" ")
        bot_service = MessagingBotService.new(platform: :telegram)

        # Handle photo messages (screenshots for conflict mediator)
        if message["photo"].present?
          photo = message["photo"].last # Highest resolution
          file_id = photo["file_id"]
          caption = message["caption"] || ""

          image_data = download_telegram_photo(file_id)
          if image_data
            reply = bot_service.process_photo(
              platform_user_id: chat_id,
              image_data: image_data,
              caption: caption,
              user_name: user_name
            )
          else
            reply = "Sorry, I couldn't download that image. Please try again."
          end

          send_telegram_response(chat_id, reply)
          return render_success
        end

        # Handle document messages (.txt files)
        if message["document"].present?
          doc = message["document"]
          file_name = doc["file_name"] || ""
          mime_type = doc["mime_type"] || ""

          if mime_type == "text/plain" || file_name.end_with?(".txt")
            file_content = download_telegram_text_file(doc["file_id"])
            if file_content
              reply = bot_service.process_text_file(
                platform_user_id: chat_id,
                text_content: file_content,
                filename: file_name,
                user_name: user_name
              )
            else
              reply = "Sorry, I couldn't read that file. Please try again."
            end
          elsif mime_type.start_with?("image/")
            image_data = download_telegram_photo(doc["file_id"])
            if image_data
              reply = bot_service.process_photo(
                platform_user_id: chat_id,
                image_data: image_data,
                caption: message["caption"] || "",
                user_name: user_name
              )
            else
              reply = "Sorry, I couldn't download that image. Please try again."
            end
          else
            reply = "I can process image files and .txt files. Please send a supported file type."
          end

          send_telegram_response(chat_id, reply)
          return render_success
        end

        # Handle text messages
        return render_success unless message["text"].present?

        text = message["text"]
        reply = bot_service.process_message(
          platform_user_id: chat_id,
          text: text,
          user_name: user_name
        )

        send_telegram_response(chat_id, reply)
        render_success
      rescue StandardError => e
        Rails.logger.error("Telegram webhook error: #{e.message}")
        render_success # Always return 200 to Telegram
      end

      private

      def handle_callback_query(callback_query)
        chat_id = callback_query.dig("message", "chat", "id")
        callback_id = callback_query["id"]
        data = callback_query["data"] || ""
        user_name = [callback_query.dig("from", "first_name"), callback_query.dig("from", "last_name")].compact.join(" ")

        # Acknowledge the button press immediately
        answer_callback_query(callback_id)

        bot_service = MessagingBotService.new(platform: :telegram)
        reply = bot_service.process_message(
          platform_user_id: chat_id,
          text: data,
          user_name: user_name
        )

        send_telegram_response(chat_id, reply)
      rescue StandardError => e
        Rails.logger.error("Telegram callback error: #{e.message}")
      end

      def answer_callback_query(callback_id)
        token = Rails.application.config.telegram_bot_token
        HTTParty.post("https://api.telegram.org/bot#{token}/answerCallbackQuery", body: {
          callback_query_id: callback_id
        })
      rescue StandardError => e
        Rails.logger.error("Telegram answerCallbackQuery error: #{e.message}")
      end

      def valid_token?
        token = params[:token] || request.headers["X-Telegram-Bot-Token"]
        token.present? && ActiveSupport::SecurityUtils.secure_compare(
          token, Rails.application.config.telegram_bot_token.to_s
        )
      end

      # Smart response: sends inline keyboard or plain text based on response type
      def send_telegram_response(chat_id, result)
        if result.is_a?(Hash) && result[:text]
          send_telegram_message(chat_id, result[:text], reply_markup: result[:reply_markup])
        else
          send_telegram_message(chat_id, result.to_s)
        end
      end

      def send_telegram_message(chat_id, text, reply_markup: nil)
        token = Rails.application.config.telegram_bot_token
        url = "https://api.telegram.org/bot#{token}/sendMessage"

        body = {
          chat_id: chat_id,
          text: text,
          parse_mode: "Markdown"
        }
        body[:reply_markup] = reply_markup.to_json if reply_markup

        response = HTTParty.post(url, body: body, timeout: 30)

        result = JSON.parse(response.body)
        unless result["ok"]
          Rails.logger.warn("Telegram Markdown failed: #{result['description']}. Retrying as plain text.")
          body.delete(:parse_mode)
          HTTParty.post(url, body: body, timeout: 30)
        end
      rescue StandardError => e
        Rails.logger.error("Telegram send error: #{e.message}")
      end

      def download_telegram_photo(file_id)
        token = Rails.application.config.telegram_bot_token

        # Get file path from Telegram
        file_info = HTTParty.get("https://api.telegram.org/bot#{token}/getFile?file_id=#{file_id}")
        result = JSON.parse(file_info.body)
        return nil unless result["ok"]

        file_path = result.dig("result", "file_path")
        return nil unless file_path

        # Download the file
        file_url = "https://api.telegram.org/file/bot#{token}/#{file_path}"
        response = HTTParty.get(file_url)
        return nil unless response.success?

        extension = File.extname(file_path).downcase
        mime_type = case extension
                    when ".jpg", ".jpeg" then "image/jpeg"
                    when ".png" then "image/png"
                    when ".webp" then "image/webp"
                    else "image/jpeg"
                    end

        {
          base64: Base64.strict_encode64(response.body),
          mime_type: mime_type
        }
      rescue StandardError => e
        Rails.logger.error("Telegram photo download error: #{e.message}")
        nil
      end

      def download_telegram_text_file(file_id)
        token = Rails.application.config.telegram_bot_token

        file_info = HTTParty.get("https://api.telegram.org/bot#{token}/getFile?file_id=#{file_id}")
        result = JSON.parse(file_info.body)
        return nil unless result["ok"]

        file_path = result.dig("result", "file_path")
        return nil unless file_path

        file_url = "https://api.telegram.org/file/bot#{token}/#{file_path}"
        response = HTTParty.get(file_url)
        return nil unless response.success?

        response.body.force_encoding("UTF-8")
      rescue StandardError => e
        Rails.logger.error("Telegram text file download error: #{e.message}")
        nil
      end
    end
  end
end
