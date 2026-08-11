import firebase_admin
from firebase_admin import credentials, messaging
from app.config import get_settings

settings = get_settings()

def init_firebase():
    if settings.FIREBASE_CREDENTIALS_PATH and not firebase_admin._apps:
        try:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            print(f"✅ Firebase Admin initialized with {settings.FIREBASE_CREDENTIALS_PATH}")
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
    else:
        print("⚠️ Firebase Admin not initialized (Missing FIREBASE_CREDENTIALS_PATH)")

def send_push_notification(token: str, title: str, body: str, data: dict = None):
    if not firebase_admin._apps:
        print("⚠️ Firebase not initialized, skipping push notification")
        return None
        
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data or {},
        token=token,
    )
    
    try:
        response = messaging.send(message)
        print(f"Successfully sent message: {response}")
        return response
    except Exception as e:
        print(f"Error sending message: {e}")
        return None
