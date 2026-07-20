import os
import warnings
from dotenv import load_dotenv

# Environment flags setup prior to framework imports
os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["NNPACK_DISABLE"] = "1"
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["TORCH_CPP_MIN_LOG_LEVEL"] = "3"
if "DEEPFACE_HOME" not in os.environ:
    os.environ["DEEPFACE_HOME"] = os.getcwd()

warnings.filterwarnings("ignore")

# Load environment variables (.env file if available)
load_dotenv(dotenv_path=".env")

# Monkey patch protobuf MessageFactory if needed before importing mediapipe
try:
    import google.protobuf.message_factory as protobuf_message_factory
    if not hasattr(protobuf_message_factory.MessageFactory, "GetPrototype"):
        def _get_prototype(self, descriptor):
            return self.GetMessageClass(descriptor)
        protobuf_message_factory.MessageFactory.GetPrototype = _get_prototype
except Exception:
    pass

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_KEY")
)
