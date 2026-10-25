#!/usr/bin/env python3
"""Build a web release using public client settings, never server credentials."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent


def client_config(config_path=None):
    # Keep public defaults in Dart, not a second copy in this script.
    # A local file is used only when explicitly selected via --config.
    data = {}
    if config_path:
        path = Path(config_path)
        if not path.is_file():
            raise ValueError('Belirtilen config dosyası bulunamadı.')
        data = json.loads(path.read_text())
        if not isinstance(data, dict):
            raise ValueError('Config bir JSON nesnesi olmalı.')
    fields = ('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')
    overrides = {k: data[k] for k in fields if k in data}
    # Empty optional GitHub Variables mean no override. Explicit empty JSON
    # values remain invalid rather than silently selecting another project.
    overrides.update({k: os.environ[k] for k in fields if os.environ.get(k)})
    if 'SUPABASE_URL' in overrides:
        url = overrides['SUPABASE_URL']
        if not isinstance(url, str):
            raise ValueError('Supabase URL metin olmalı.')
        parts = urlsplit(url)
        if (parts.scheme != 'https' or not parts.hostname or parts.username or parts.password
                or parts.query or parts.fragment or parts.path not in ('', '/')):
            raise ValueError('Geçerli HTTPS Supabase URL gerekli.')
    if 'SUPABASE_PUBLISHABLE_KEY' in overrides:
        key = overrides['SUPABASE_PUBLISHABLE_KEY']
        if not isinstance(key, str) or not key.startswith('sb_publishable_') or key.strip() != key:
            raise ValueError('Yalnızca publishable istemci anahtarı kabul edilir.')
    return overrides or None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-href', default='/')
    parser.add_argument('--config')
    args = parser.parse_args()
    if not args.base_href.startswith('/') or not args.base_href.endswith('/'):
        parser.error('--base-href başında ve sonunda / olmalı.')
    try:
        config = client_config(args.config)
    except (ValueError, OSError, TypeError):
        # Do not echo invalid input or parser exceptions that could contain a key.
        parser.error('İstemci yapılandırması geçersiz. URL/publishable key ayarlarını kontrol edin.')
    command = [os.environ.get('FLUTTER_BIN', 'flutter'), 'build', 'web', '--release',
               '--base-href', args.base_href, '--no-web-resources-cdn']
    with tempfile.TemporaryDirectory(prefix='mobilab-web-') as temp:
        if config:
            path = Path(temp) / 'client.json'
            path.write_text(json.dumps(config))
            command.append('--dart-define-from-file=' + str(path))
        print('Web build: ' + ('açık istemci override' if config else 'public demo varsayılanları'), flush=True)
        subprocess.run(command, cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
