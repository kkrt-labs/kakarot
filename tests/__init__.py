import yaml
from pathlib import Path


class Object():
    pass


def update(ref: dict, new: dict) -> dict:
    """Update ref recursively with new."""
    for key, value in new.items():
        if isinstance(value, dict):
            ref[key] = update(ref.get(key, {}), value)
        else:
            ref[key] = value
    return ref


def objectify(parent: object, attributes: dict) -> object:
    """Set attributes recursively to parent object."""
    for key, value in attributes.items():
        if isinstance(value, dict):
            value = objectify(Object(), value)
        setattr(parent, key, value)
    return parent


def load(path: str, context: object):
    """Read config files and setup context."""
    # load config
    path = Path(path)
    config = {}
    for parent in reversed(path.parents):
        config_path = parent / path.name
        if not config_path.exists():
            continue
        with open(config_path, 'r') as file_instance:
            update(config, yaml.safe_load(file_instance))

    # set up context
    context = objectify(context, config)
