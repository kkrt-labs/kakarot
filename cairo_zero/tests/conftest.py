import logging
import os

from dotenv import load_dotenv
from hypothesis import Phase, Verbosity, settings

load_dotenv()
logging.getLogger("asyncio").setLevel(logging.ERROR)
logger = logging.getLogger()

settings.register_profile(
    "nightly",
    deadline=None,
    max_examples=1500,
    phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target],
)
settings.register_profile(
    "ci",
    deadline=None,
    max_examples=100,
    phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target],
)
settings.register_profile(
    "dev",
    deadline=None,
    max_examples=10,
    phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target],
)
settings.register_profile(
    "debug",
    max_examples=10,
    verbosity=Verbosity.verbose,
    phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target],
)
settings.load_profile(os.getenv("HYPOTHESIS_PROFILE", "default"))
logger.info(f"Using Hypothesis profile: {os.getenv('HYPOTHESIS_PROFILE', 'default')}")
