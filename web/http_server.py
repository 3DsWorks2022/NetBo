#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自定义HTTP服务器，正确设置MIME类型
解决手机浏览器显示文件下载的问题
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

# MIME类型映射
MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.htm': 'text/html; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.m3u8': 'application/vnd.apple.mpegurl',
    '.ts': 'video/mp2t',
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.txt': 'text/plain; charset=utf-8',
    '.xml': 'application/xml; charset=utf-8',
}

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """自定义HTTP请求处理器，正确设置MIME类型"""
    
    def __init__(self, *args, **kwargs):
        # 获取web目录作为基础目录
        web_dir = kwargs.pop('directory', None)
        if web_dir:
            os.chdir(web_dir)
        super().__init__(*args, directory=None, **kwargs)
    
    def end_headers(self):
        # 添加CORS头（必须在所有响应中添加）
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS, HEAD')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type, Accept')
        self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range')
        
        # 对于HLS文件，禁用缓存
        if self.path.endswith('.m3u8') or self.path.endswith('.ts'):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            # 对于TS文件，支持范围请求
            if self.path.endswith('.ts'):
                self.send_header('Accept-Ranges', 'bytes')
        
        super().end_headers()
    
    def do_OPTIONS(self):
        """处理OPTIONS预检请求"""
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS, HEAD')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type, Accept')
        self.send_header('Access-Control-Max-Age', '1728000')
        self.send_header('Content-Length', '0')
        self.end_headers()
    
    def guess_type(self, path):
        """重写MIME类型猜测方法"""
        # 获取文件扩展名
        ext = Path(path).suffix.lower()
        
        # 如果扩展名在映射中，返回对应的MIME类型
        if ext in MIME_TYPES:
            return MIME_TYPES[ext]
        
        # 默认使用父类的方法
        return super().guess_type(path)
    
    def translate_path(self, path):
        """重写路径转换方法，支持HLS文件的特殊路径"""
        # 处理HLS文件的特殊路径 /hls/xxx
        if path.startswith('/hls/'):
            # 获取文件名（去掉/hls/前缀）
            filename = path[5:]  # /hls/stream.m3u8 -> stream.m3u8
            
            # 获取当前工作目录（web目录）
            web_dir = os.getcwd()
            
            # 优先检查web目录下的hls目录（符号链接或真实目录）
            hls_dirs = []
            
            # 1. 检查web/hls目录（符号链接或真实目录）- 最优先
            hls_in_web = os.path.join(web_dir, 'hls')
            if os.path.exists(hls_in_web):
                hls_dirs.append(hls_in_web)
            
            # 2. 检查其他可能的HLS目录位置
            hls_dirs.extend([
                '/var/www/hls',  # Ubuntu部署路径
                os.path.join(web_dir, 'hls_output'),  # web目录下的hls_output
                os.path.join(os.path.dirname(web_dir), 'hls_output'),  # 项目根目录下的hls_output
            ])
            
            # 查找实际存在的文件
            for hls_dir in hls_dirs:
                hls_file = os.path.join(hls_dir, filename)
                if os.path.exists(hls_file) and os.path.isfile(hls_file):
                    # 对于SimpleHTTPRequestHandler，需要返回相对于当前工作目录的路径
                    # 如果文件在web目录下，使用相对路径
                    try:
                        # 计算相对于web目录的路径
                        rel_path = os.path.relpath(hls_file, web_dir)
                        # 使用相对路径（相对于web目录）
                        return os.path.normpath(os.path.join(web_dir, rel_path))
                    except:
                        # 如果计算失败，直接返回绝对路径
                        return os.path.normpath(hls_file)
        
        # 默认处理（调用父类方法）
        return super().translate_path(path)
    
    def do_GET(self):
        """处理GET请求"""
        # 如果路径是目录，尝试查找index.html
        if self.path.endswith('/') or self.path == '':
            self.path = '/index.html'
        
        # 调用父类的GET处理
        return super().do_GET()
    
    def log_message(self, format, *args):
        """重写日志方法，静默处理连接重置错误"""
        # 静默处理常见的连接错误
        if 'Connection reset by peer' in str(args) or 'Broken pipe' in str(args):
            return
        super().log_message(format, *args)

def run_server(port=8080, directory=None):
    """启动HTTP服务器"""
    if directory:
        os.chdir(directory)
    
    handler = CustomHTTPRequestHandler
    
    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"服务器启动在端口 {port}")
        print(f"访问地址: http://localhost:{port}/index.html")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务器已停止")
            sys.exit(0)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='启动自定义HTTP服务器')
    parser.add_argument('-p', '--port', type=int, default=8080, help='端口号 (默认: 8080)')
    parser.add_argument('-d', '--directory', type=str, default=None, help='服务目录 (默认: 当前目录)')
    
    args = parser.parse_args()
    
    run_server(port=args.port, directory=args.directory)
