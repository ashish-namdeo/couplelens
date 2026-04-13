# Product Requirements Document (PRD): CoupleLens (Updated)

---

## 1. Product Vision & Overview

### 1.1 Vision
CoupleLens is envisioned as the world's first **Relationship Operating System**, providing an intelligent platform that helps couples navigate every stage of their relationship—from early connection to long-term stability.

### 1.2 Platform Overview
The platform integrates AI-powered tools, therapist services, and guided programs to enhance communication, resolve conflicts, and strengthen relationships.

---

## 2. Core Platform Modules (Revised)

### 2.1 AI Tools (Unified Experience)

All AI-powered features are consolidated under a single **“AI Tools” dropdown** to simplify navigation and improve discoverability.

#### Included Features (with Updated UI Headings):

- **Talk to AI Advisor** *(formerly AI Relationship Assistant)*
- **Resolve a Conflict** *(formerly AI Conflict Mediator)*
- **Improve Your Message** *(formerly AI Conversation Rewrite Tool)*
- **Check Your Compatibility** *(formerly Compatibility Assessment Engine — now merged here)*

**Goal:**  
Provide a centralized, intuitive access point for all AI-driven relationship tools.

---

### 2.2 Therapist Marketplace

A vetted directory of licensed professionals.

**UI Heading:** *Find a Therapist*

---

### 2.3 Therapist Booking System

Seamless scheduling for therapy sessions (video, voice, chat).

**UI Heading:** *Book a Session*

---

### 2.4 Relationship Growth Programs

Structured programs like trust building, pre-marriage preparation, etc.

**UI Heading:** *Guided Relationship Programs*

---

### 2.5 Workshops & Retreats

Marketplace for live workshops and therapy retreats.

**UI Heading:** *Workshops & Retreats*

---

### 2.6 Couple Financial Tools

Shared budgeting and expense tracking.

**UI Heading:** *Manage Finances Together*

---

### 2.7 Couple Memory Timeline

Private shared space for memories and milestones.

**UI Heading:** *Your Relationship Timeline*

---

## 3. Features Hidden from UI (Important Update)

To improve simplicity and reduce cognitive load, certain features will be **hidden from the user interface**:

- Relationship Health Dashboard  
- Features previously grouped under the **“More” section** (low priority / less frequently used)

**Note:**  
These features are not removed from the system and may be reintroduced in future iterations based on user feedback.

---

## 4. Navigation & Information Architecture (Updated)

### Primary Navigation Structure:

- AI Tools  
- Therapy & Services *(Therapist Marketplace + Booking)*  
- Growth Programs  
- Workshops & Retreats  
- Finances  
- Timeline  

### Key Changes:

- Removed dependency on “More” menu  
- Simplified top-level navigation  
- Grouped related features logically  

---

## 5. UI/UX Enhancements

### 5.1 Heading & Content Improvements

**Objective:**  
Enhance the web UI by refining headings and labels across the platform.

**Key Improvements:**

- Replace technical or unclear labels with **user-friendly language**
- Maintain **consistent naming conventions**
- Improve **readability and clarity**
- Align headings with **user intent and actions**

---

### 5.2 Microcopy Enhancements

Add short descriptive texts under key headings:

- **Talk to AI Advisor** → “Get guidance on your relationship anytime”  
- **Resolve a Conflict** → “Find balanced solutions together”  
- **Improve Your Message** → “Make your words calmer and clearer”  
- **Check Your Compatibility** → “Understand your strengths and differences”  

---

## 6. User Roles & Capabilities

- **User (Couple Member):** Access AI tools, programs, and therapist services  
- **Therapist:** Manage profile, availability, and sessions  
- **Admin:** Manage platform operations and approvals  

---

## 7. Revenue Model & Monetization Strategy

- Premium Subscriptions  
- Marketplace Commission  
- One-off Purchases  
- Event Commission  

---

## 8. Technology Architecture

- Backend: Ruby on Rails  
- Frontend: Hotwire (Turbo + Stimulus) + Bootstrap  
- Database: PostgreSQL  
- AI: OpenAI API  
- Payments: Stripe  
- Background Jobs: Sidekiq + Redis  
- Storage: AWS S3  

---

## 9. Security & Compliance

- Multi-Factor Authentication (MFA)  
- End-to-end encryption for chat  
- HIPAA compliance readiness  
- GDPR/CCPA compliance  

---

## 10. Scalability Strategy

- Modular Rails monolith architecture  
- Background processing for AI and notifications  
- Caching using Redis  

---

## 11. Success Metrics (KPIs)

- Monthly Active Users (MAU) / Daily Active Users (DAU)  
- Subscription Conversion Rate  
- Therapist Booking Rate  
- User engagement with AI Tools  

---

## ✅ Summary of Updates

- Centralized all AI features under **AI Tools dropdown**  
- Moved **Compatibility Assessment into AI Tools**  
- Hidden **Health Dashboard and “More” section features**  
- Improved **navigation structure**  
- Enhanced **UI headings and microcopy for better clarity**  

---