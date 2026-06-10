from http.server import BaseHTTPRequestHandler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        
        html = """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Contact Us - J-news</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 40px auto; padding: 20px; }
                .container { background: #f9f9f9; padding: 30px; border-radius: 12px; border: 1px solid #eee; }
                h1 { color: #1a2744; font-size: 24px; margin-bottom: 20px; }
                .info-item { margin-bottom: 15px; }
                .label { font-weight: bold; color: #666; display: block; font-size: 14px; }
                .value { font-size: 18px; color: #1a2744; font-weight: 600; }
                .footer { margin-top: 30px; font-size: 12px; color: #999; text-align: center; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Contact Us / 문의하기</h1>
                <p>J-news 앱 서비스와 관련된 문의, 피드백, 뉴스 콘텐츠 제보 등은 아래의 공식 채널을 이용해 주세요.</p>
                
                <div class="info-item">
                    <span class="label">운영 주체 (Operator)</span>
                    <span class="value">k-jieum</span>
                </div>
                
                <div class="info-item">
                    <span class="label">이메일 (Customer Support)</span>
                    <span class="value"><a href="mailto:xowns142857@gmail.com">xowns142857@gmail.com</a></span>
                </div>
                
                <div class="info-item">
                    <span class="label">웹사이트 URL</span>
                    <span class="value">https://backend-ruby-chi-85.vercel.app/contact</span>
                </div>
            </div>
            <div class="footer">
                &copy; 2024 J-news · k-jieum. All rights reserved.
            </div>
        </body>
        </html>
        """
        self.wfile.write(html.encode('utf-8'))
        return
