#!/usr/bin/env python3
"""Local review gallery with atomic, dataset-scoped human feedback persistence."""
import argparse
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading
from urllib.parse import urlsplit, parse_qs

ROOT = Path(__file__).resolve().parents[2]


class ReviewHandler(SimpleHTTPRequestHandler):
    lock = threading.Lock()

    def feedback_path(self):
        test = parse_qs(urlsplit(self.path).query).get('test') == ['1']
        return Path(self.directory) / ('feedback-test.json' if test else 'feedback.json')

    def read_feedback(self):
        path = self.feedback_path()
        if path.exists():
            data = json.loads(path.read_text())
            if (data['sourceSHA256'] != self.server.dataset['sourceSHA256']
                    or data.get('reviewId') != self.server.dataset.get('reviewId')):
                raise ValueError('Feedback dataset mismatch')
            return data
        return dict(schemaVersion=1, meaning='agreement_with_filter_verdict',
                    reviewId=self.server.dataset.get('reviewId'),
                    sourceSHA256=self.server.dataset['sourceSHA256'],
                    seed=self.server.dataset['seed'], thresholds=self.server.dataset['thresholds'], records={})

    def respond(self, status, data):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if urlsplit(self.path).path == '/api/feedback':
            try:
                with self.lock:
                    self.respond(200, self.read_feedback())
            except (ValueError, OSError, KeyError) as error:
                self.respond(500, dict(error=str(error)))
        else:
            super().do_GET()

    def do_POST(self):
        if urlsplit(self.path).path != '/api/feedback':
            return self.respond(404, dict(error='Unknown endpoint'))
        origin = self.headers.get('Origin')
        if origin and origin != 'http://' + self.headers.get('Host', ''):
            return self.respond(403, dict(error='Same-origin requests required'))
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 12000:
                raise ValueError('Invalid body size')
            request = json.loads(self.rfile.read(size))
            sample = self.server.samples[request['id']]
            if (request['sourceSHA256'] != self.server.dataset['sourceSHA256']
                    or request.get('reviewId') != self.server.dataset.get('reviewId')):
                raise ValueError('Dataset mismatch')
            if type(request['agrees']) is not bool:
                raise ValueError('agrees must be boolean')
            note = request.get('note', '')
            if not isinstance(note, str) or len(note) > 1000:
                raise ValueError('Invalid note')
            record = dict(id=sample['id'], number=sample['number'],
                          algorithmStatus=sample['status'], agrees=request['agrees'],
                          expectedStatus=sample['status'] if request['agrees'] else ('drop' if sample['status']=='keep' else 'keep'),
                          note=note, comparedPocket=request.get('comparedPocket'),
                          reviewed=True, updatedAt=datetime.now(timezone.utc).isoformat())
            if record['comparedPocket'] not in range(6):
                raise ValueError('Invalid compared pocket')
            with self.lock:
                data = self.read_feedback()
                data['records'][sample['id']] = record
                path = self.feedback_path()
                temporary = path.with_suffix('.tmp')
                temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
                temporary.replace(path)
            self.respond(200, record)
        except (ValueError, KeyError, TypeError) as error:
            self.respond(400, dict(error=str(error)))
        except OSError as error:
            self.respond(500, dict(error=str(error)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8766)
    parser.add_argument('--directory', type=Path, default=ROOT/'output/two-ball-pocket-filter-20261024/review-1000')
    args = parser.parse_args()
    folder = args.directory.resolve()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(ReviewHandler, directory=str(folder)))
    server.dataset = json.loads((folder/'samples.json').read_text())
    server.samples = {s['id']: s for s in server.dataset['samples']}
    print(f'Review: http://127.0.0.1:{args.port}/', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
