Project done by Faruk Basic, Almir Bajric, Minad Kamberovic and Ammar Haljkovic 
# VacationCatcher (Barebones Version)

VacationCatcher is a mobile app designed to let friends easily share and manage vacation photos in shared albums. This version is just the **bare skeleton**, providing basic album creation, image uploading, and viewing functionality.

## Features (Current Version)
- **Create Albums**: Users can create albums to store vacation photos.
- **Add Photos**: Upload images from the gallery into albums.
- **Edit Albums**: Rename albums and remove unwanted photos.
- **View Photos**: Tap an image to zoom in and scroll through album photos.
- **Exit Photo View**: Swipe **left or right** to exit full-screen image view.

## Features NOT Included Yet
- No **Firebase or cloud storage** (local storage only for now).
- No **user authentication** (no Google sign-in yet).
- No **online sync** (albums are stored only on the local device).

## Tech Stack
- **Flutter** (UI framework)
- **Dart** (programming language)
- **Image Picker** (for selecting images from gallery)
- **Photo View** (for zooming & swiping through images)

## How to Run
1. **Clone the repository**:
   ```sh
   git clone https://github.com/ammarhaljk/VacationCatcher.git
   cd VacationCatcher
   ```
2. **Install dependencies**:
   ```sh
   flutter pub get
   ```
3. **Run the app**:
   ```sh
   flutter run
   ```

## Future Improvements
Add Firebase integration for cloud storage.
Implement Google sign-in for authentication.
Enable online album sharing between users.

This is an **early prototype**, and improvements will be made in future updates.

