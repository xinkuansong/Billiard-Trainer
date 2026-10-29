from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from urllib.parse import urlparse,parse_qs
import json,sqlite3,zlib
from scan import OUT
ORDER_BY='route,axis'
PAGE_SIZE=6


class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(OUT),**kwargs)
    def do_GET(self):
        url=urlparse(self.path)
        if url.path!='/api':return super().do_GET()
        query=parse_qs(url.query);where=[];values=[]
        allowed={'grade':{'1','2','3'},'axis':{'inAngle','outAngle'},'rail':{'1','2','3'},'pocket':{'middle','corner'}}
        for key,choices in allowed.items():
            value=query.get(key,[''])[0]
            if value in choices:where.append(key+'=?');values.append(value)
        route=query.get('route',[''])[0]
        if route:where.append('route=?');values.append(route)
        try:page=max(0,int(query.get('page',['0'])[0]))
        except ValueError:page=0
        clause=' WHERE '+' AND '.join(where) if where else ''
        db=sqlite3.connect(f'file:{OUT}/atlas.sqlite?mode=ro',uri=True)
        total=db.execute('SELECT count(*) FROM questions'+clause,values).fetchone()[0]
        page=min(page,max(0,(total-1)//PAGE_SIZE))
        rows=[json.loads(zlib.decompress(r[0])) for r in db.execute('SELECT data FROM questions'+clause+' ORDER BY '+ORDER_BY+' LIMIT ? OFFSET ?',values+[PAGE_SIZE,page*PAGE_SIZE])];db.close()
        body=json.dumps(dict(total=total,page=page,rows=rows),ensure_ascii=False).encode()
        self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)


if __name__=='__main__':
    import argparse
    from pathlib import Path
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=OUT)
    parser.add_argument('--port',type=int,default=8859)
    parser.add_argument('--sample-order',action='store_true')
    parser.add_argument('--page-size',type=int,choices=(6,100),default=6)
    args=parser.parse_args();OUT=args.output.resolve()
    PAGE_SIZE=args.page_size
    if args.sample_order:ORDER_BY='sample_order'
    ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
