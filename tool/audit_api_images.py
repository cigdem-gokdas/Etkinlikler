#!/usr/bin/env python3
"""Explicit live audit, outside CI. Bounded GETs; never changes server data.

python3 tool/audit_api_images.py --output /private/tmp/mobilab-api-image-audit
flutter test tool/audit_image_decode_test.dart --dart-define=AUDIT_MANIFEST=/private/tmp/mobilab-api-image-audit/manifest.json
"""
import argparse
import concurrent.futures
import json
from pathlib import Path
import subprocess
import time
from urllib.parse import quote, urlencode, urlsplit

BASE = 'https://mobilab-task-api.vercel.app'


def get(url, target):
    for attempt in range(2):
        result = subprocess.run([
            'curl', '-sS', '-L', '--proto', '=https,http', '--proto-redir', '=https,http',
            '--connect-timeout', '5', '--max-time', '18', '--max-filesize', '8388608',
            '--output', str(target), '--write-out', '%{json}', url,
        ], capture_output=True, text=True)
        try:
            metadata = json.loads(result.stdout)
        except ValueError:
            metadata = {}
        record = dict(http=metadata.get('http_code', 0),
                      content_type=metadata.get('content_type', ''),
                      curl_exit=result.returncode, attempts=attempt + 1)
        if result.returncode == 0 and record['http'] < 500:
            return record
        if attempt == 0:
            time.sleep(.7)
    return record


def read_json(path, response):
    if response['curl_exit'] or response['http'] != 200:
        return None
    try:
        return json.loads(path.read_text())
    except (ValueError, OSError, UnicodeError):
        return None


def url_kind(event):
    if 'imageUrl' not in event:
        return 'missing'
    value = event['imageUrl']
    if value is None:
        return 'null'
    if not isinstance(value, str):
        return 'invalid-type'
    if not value.strip():
        return 'empty'
    try:
        parts = urlsplit(value)
        if parts.scheme not in ('http', 'https') or not parts.hostname or parts.username:
            return 'invalid-url'
    except ValueError:
        return 'invalid-url'
    return 'url'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    out = parser.parse_args().output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    audit = dict(api=BASE, pages=[], events=[], images=[], errors=[])
    ids = set()
    for page in range(1, 21):
        path = out / f'page-{page}.json'
        response = get(BASE + '/events?' + urlencode(dict(page=page, limit=10)), path)
        body = read_json(path, response)
        audit['pages'].append(dict(page=page, **response))
        if not isinstance(body, dict) or not isinstance(body.get('items'), list):
            audit['errors'].append(f'Page {page} unavailable or invalid JSON')
            break
        added = 0
        for event in body['items']:
            if not isinstance(event, dict) or not isinstance(event.get('id'), str):
                audit['errors'].append(f'Page {page} invalid event')
                continue
            if event['id'] in ids:
                continue
            ids.add(event['id'])
            added += 1
            audit['events'].append(dict(id=event['id'], title=event.get('title'),
                list_image_kind=url_kind(event), list_image_url=event.get('imageUrl')))
        audit['pages'][-1].update(total=body.get('total'), has_more=body.get('hasMore'), count=len(body['items']))
        if body.get('hasMore') is False:
            break
        if body.get('hasMore') is not True or not added:
            audit['errors'].append('Pagination made no progress or hasMore invalid')
            break
    else:
        audit['errors'].append('Maximum 20 pages reached')

    def detail(item):
        path = out / ('detail-' + quote(item['id'], safe='') + '.json')
        response = get(BASE + '/events/' + quote(item['id'], safe=''), path)
        body = read_json(path, response)
        item['detail_response'] = response
        if isinstance(body, dict) and body.get('id') == item['id']:
            item.update(detail_image_kind=url_kind(body), detail_image_url=body.get('imageUrl'))
        else:
            item['detail_error'] = 'Unavailable, invalid JSON or mismatched ID'
        return item

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        audit['events'] = list(pool.map(detail, audit['events']))
    urls = list(dict.fromkeys(
        e[field] for e in audit['events']
        for kind, field in [('list_image_kind', 'list_image_url'), ('detail_image_kind', 'detail_image_url')]
        if e.get(kind) == 'url'))

    def image(entry):
        index, url = entry
        path = out / f'image-{index:02}.bin'
        return dict(url=url, path=str(path), **get(url, path))

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        audit['images'] = list(pool.map(image, enumerate(urls)))
    manifest = out / 'manifest.json'
    manifest.write_text(json.dumps(audit, ensure_ascii=False, indent=2))
    print(json.dumps(dict(manifest=str(manifest), events=len(audit['events']),
        pages=len(audit['pages']), unique_image_urls=len(urls), errors=audit['errors']), ensure_ascii=False))


if __name__ == '__main__':
    main()
