import hashlib
import hmac
import secrets


def password_hash(password):
    if not isinstance(password, str) or not 12 <= len(password) <= 256:
        raise ValueError("Admin passwords must contain 12 to 256 characters")
    salt = secrets.token_hex(16)
    derived = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=32768, r=8, p=1, maxmem=67108864)
    return "scrypt$" + salt + "$" + derived.hex()


def verify_password(password, encoded):
    try:
        scheme, salt, expected = encoded.split("$")
        if scheme != "scrypt" or len(salt) != 32 or len(expected) != 128:
            return False
        derived = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=32768, r=8, p=1, maxmem=67108864)
        return hmac.compare_digest(derived.hex(), expected)
    except (ValueError, AttributeError):
        return False
