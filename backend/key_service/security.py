import hashlib
import hmac
import secrets
from ipaddress import ip_address, ip_network


SCRYPT_N = 131072
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_MAXMEM = 268435456


def password_hash(password):
    if not isinstance(password, str) or not 15 <= len(password) <= 256:
        raise ValueError("Admin passwords must contain 15 to 256 characters")
    salt = secrets.token_hex(16)
    derived = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=SCRYPT_N, r=SCRYPT_R, p=SCRYPT_P, maxmem=SCRYPT_MAXMEM)
    return f"scrypt${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}$" + salt + "$" + derived.hex()


def verify_password(password, encoded):
    try:
        if not isinstance(password, str) or not 1 <= len(password) <= 256:
            return False
        parts = encoded.split("$")
        if len(parts) == 3:
            scheme, salt, expected = parts
            n, r, p = 32768, 8, 1  # Existing installations remain readable during migration.
        elif len(parts) == 6:
            scheme, raw_n, raw_r, raw_p, salt, expected = parts
            n, r, p = int(raw_n), int(raw_r), int(raw_p)
            if (n, r, p) != (SCRYPT_N, SCRYPT_R, SCRYPT_P):
                return False
        else:
            return False
        if scheme != "scrypt" or len(salt) != 32 or len(expected) != 128:
            return False
        expected_bytes = bytes.fromhex(expected)
        derived = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=n, r=r, p=p, maxmem=SCRYPT_MAXMEM)
        return hmac.compare_digest(derived, expected_bytes)
    except (ValueError, AttributeError, TypeError):
        return False


def client_address(request):
    # Only Vercel's runtime may trust its proxy-supplied address. Local servers
    # use the transport peer, never arbitrary Forwarded/X-Forwarded-For headers.
    if request.app.state.vercel:
        value = request.headers.get("x-vercel-forwarded-for", "").split(",", 1)[0].strip()
        try:
            return str(ip_address(value))
        except ValueError:
            pass
    return request.client.host if request.client else "unknown"


def login_network(address):
    # IPv6 privacy addresses in one /64 share a login budget.
    try:
        parsed = ip_address(address)
        return str(ip_network(f"{parsed}/64", strict=False)) if parsed.version == 6 else str(parsed)
    except ValueError:
        return "unknown"
