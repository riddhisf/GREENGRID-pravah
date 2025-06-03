# Pravah

Pravah is an innovative mobile application designed to revolutionize rural development through AI-powered resource allocation and sustainable energy management. The app leverages Google's Gemini AI to provide intelligent recommendations for renewable energy adoption, optimize resource utilization, and promote sustainable practices in rural communities.

Through its intuitive interface, Pravah offers real-time data analytics, location-based energy predictions, and sustainable waste management solutions. The integration of Google's Gemini AI enables precise predictions for renewable energy potential and provides personalized sustainability guidance, making it an essential tool for rural communities to embrace clean energy alternatives.

Built with Flutter for cross-platform functionality, Firebase for robust backend services, and Gemini AI for intelligent analysis, Pravah provides an intuitive platform for rural communities to embrace sustainable development and contribute to environmental conservation.

## Features

- **AI-Powered Energy Prediction**: Uses Gemini to predict optimal renewable energy sources (solar, wind) based on location-specific data
- **Real-Time Energy Monitoring**: Tracks daily energy generation, savings, and carbon footprint reduction
- **Sustainable Waste Management**: AI-driven image
  analysis for customized waste processing suggestions.
- **Location-Based Analysis**: Recommends best-suited renewable energy sources for specific areas.
- **AI Chatbot**: Personalized sustainability guidance and support for rural communities.

## Tech Stack

| Technology      | Description                                   |
| --------------- | --------------------------------------------- |
| Flutter         | Cross-platform mobile application development |
| Firebase        | Authentication and data management            |
| Gemini AI        | Location-based energy prediction              |
| Gemini AI       | Chatbot and waste management solutions        |
| Google Maps API | Location services and geospatial analysis     |
| OpenWeather API | Real-time weather data for energy predictions |

<img src="pravah/lib/assets/images/Flowchart.jpeg" alt="Pravah Logo" width="550"/>

## App Screenshots

<p float="left">
  <img src="pravah/lib/assets/images/home.jpeg" width="200" />
  <img src="pravah/lib/assets/images/home2.jpeg" width="200" /> 
  <img src="pravah/lib/assets/images/login.jpeg" width="200" />
  <img src="pravah/lib/assets/images/profile.jpeg" width="200" />
</p>

<p float="left">
  <img src="pravah/lib/assets/images/profile2.jpeg" width="200" />
  <img src="pravah/lib/assets/images/carbon.jpeg" width="200" />
  <img src="pravah/lib/assets/images/chatbot.jpeg" width="200" />
  <img src="pravah/lib/assets/images/location.jpeg" width="200" />
</p>

<p float="left">
  <img src="pravah/lib/assets/images/solarsetup.jpeg" width="200" />
  <img src="pravah/lib/assets/images/solarsetup2.jpeg" width="200" />
  <img src="pravah/lib/assets/images/windsetup.jpeg" width="200" />
  <img src="pravah/lib/assets/images/windsetup2.jpeg" width="200" />
</p>

<p float="left">
  <img src="pravah/lib/assets/images/solution.jpeg" width="200" />
  <img src="pravah/lib/assets/images/solution2.jpeg" width="200" />
  <img src="pravah/lib/assets/images/solution3.jpeg" width="200" />
  <img src="pravah/lib/assets/images/suggestions.jpeg" width="200" />
</p>

<p float="left">
  <img src="pravah/lib/assets/images/tracking.jpeg" width="200" />
  <img src="pravah/lib/assets/images/alerts.jpeg" width="200" />
</p>

## Installation

### Requirements

- Compatible with Android, iOS, Windows, and macOS
- Flutter SDK ^3.6.1
- API keys for Gemini AI and weather services

#### Installation Methods

### Direct Installation

[Click Here](https://drive.google.com/file/d/1sjnf4oGpTNt6UHEJSUYHBWy2yXvq1Nj0/view?usp=sharing)

### Manual Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/007divyanshu/pravah.git
   ```

2. Navigate to project directory:

   ```bash
   cd pravah
   ```

3. Create .env file with required keys:

   ```env
   # Firebase Configuration (Web)
    FIREBASE_API_KEY_WEB=your_firebase_api_key_web
    FIREBASE_APP_ID_WEB=your_firebase_app_id_web
    FIREBASE_MESSAGING_SENDER_ID=your_firebase_messaging_sender_id
    FIREBASE_PROJECT_ID=your_firebase_project_id
    FIREBASE_AUTH_DOMAIN=your_firebase_auth_domain
    FIREBASE_STORAGE_BUCKET=your_firebase_storage_bucket
    
    # Firebase Configuration (Android)
    FIREBASE_API_KEY_ANDROID=your_firebase_api_key_android
    FIREBASE_APP_ID_ANDROID=your_firebase_app_id_android
    
    # Firebase Configuration (iOS)
    FIREBASE_API_KEY_IOS=your_firebase_api_key_ios
    FIREBASE_APP_ID_IOS=your_firebase_app_id_ios
    FIREBASE_IOS_BUNDLE_ID=your_firebase_ios_bundle_id
    
    # API Keys
    GEMINI_API_KEY=your_gemini_api_key
    GOOGLE_MAP_API_KEY=your_google_map_api_key
    AI_API_KEY=your_ai_api_key
    WEATHER_API_KEY=your_weather_api_key
   ```

4. Install dependencies:

   ```bash
   flutter pub get
   ```

5. Run the app:
   ```bash
   flutter run
   ```

## App Demo Video

[Add YouTube badge/link when available]

## Important Notes

- API keys are removed for security reasons
- Requires proper setup of Firebase project and Gemini AI access
- Internet connection required for AI features and real-time data
- Currently optimized for Android platforms.
