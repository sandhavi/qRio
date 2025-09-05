# Firestore Security Rules Setup

## ⚠️ Important: Fix Permission Errors

If you're seeing "PERMISSION_DENIED" errors in the console, you need to update your Firestore security rules in the Firebase Console.

## Steps to Fix:

1. **Go to Firebase Console**
   - Open [Firebase Console](https://console.firebase.google.com)
   - Select your project

2. **Navigate to Firestore Database**
   - Click on "Firestore Database" in the left menu
   - Go to the "Rules" tab

3. **Update Security Rules**
   - Replace the existing rules with the content from `firestore.rules` file
   - Or copy and paste these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read and write their own user document
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to create and read sessions
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null;
      
      // Allow authenticated users to read and write messages in sessions
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
      
      // Allow authenticated users to read and write typing status
      match /typing/{document} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

4. **Publish the Rules**
   - Click the "Publish" button
   - Wait for the rules to be deployed (usually takes a few seconds)

## What These Rules Do:

- **Users Collection**: Users can only read/write their own user document
- **Sessions Collection**: Any authenticated user can read/write sessions and their subcollections
- **Messages Subcollection**: Authenticated users can read/write messages
- **Typing Subcollection**: Authenticated users can read/write typing status

## Note:
The app will still work even if these rules aren't updated immediately, but some features like user profiles and typing indicators may not function properly until the rules are applied.