import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;

import '../models/chat.dart';

class _FetchResult {
  final int statusCode;
  final String contentType;
  final List<int> bytes;
  const _FetchResult(
      {required this.statusCode,
      required this.contentType,
      required this.bytes});
}

/// Browser (beta): downloads pages linked in the user's message and turns
/// them into clean text the model can read — so even a 1B model can "browse".
class WebFetchService {
  static final RegExp _urlRe =
      RegExp(r'''https?://[^\s<>"'\)\]]+''', caseSensitive: false);

  // Block-level tags: a newline is injected after each closing tag before
  // parsing, so the extracted text keeps paragraph structure.
  static final RegExp _blockRe = RegExp(
      r'<(br|/p|/div|/li|/h[1-6]|/tr|/section|/article|/blockquote|/pre|/td)[^>]*>',
      caseSensitive: false);

  // Non-content elements dropped from the DOM before text extraction.
  static const _junkTags = [
    'script', 'style', 'noscript', 'svg', 'iframe',
    'nav', 'header', 'footer', 'aside', 'form', 'template',
  ];

  static List<String> extractUrls(String text, {int max = 3}) {
    final urls = <String>{};
    for (final m in _urlRe.allMatches(text)) {
      var u = m.group(0)!;
      while (u.isNotEmpty && '.,;:!?'.contains(u[u.length - 1])) {
        u = u.substring(0, u.length - 1);
      }
      urls.add(u);
      if (urls.length >= max) break;
    }
    return urls.toList();
  }

  static Future<WebSnippet> fetch(String url, {int maxChars = 8000}) async {
    // The client is owned here (not by _get) so a timeout can force-close a
    // stalled connection; otherwise the dangling socket keeps the VM busy.
    final hc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/126.0.0.0 Mobile Safari/537.36';
    try {
      final res = await _get(hc, Uri.parse(url))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode >= 400) {
        return WebSnippet(url: url, error: 'HTTP ${res.statusCode}');
      }
      if (res.statusCode >= 300) {
        return WebSnippet(url: url, error: 'redirect loop');
      }

      final body = utf8.decode(res.bytes, allowMalformed: true);
      final type = res.contentType.toLowerCase();
      String title = '';
      String text;
      if (type.contains('html') || _looksHtml(body)) {
        final doc = html_parser
            .parse(body.replaceAllMapped(_blockRe, (m) => '${m.group(0)}\n'));
        title = doc.querySelector('title')?.text.trim() ?? '';
        for (final tag in _junkTags) {
          for (final e in doc.querySelectorAll(tag)) {
            e.remove();
          }
        }
        text = doc.body?.text ?? '';
      } else if (type.contains('text/') ||
          type.contains('json') ||
          type.contains('xml')) {
        text = body;
      } else {
        return WebSnippet(url: url, error: type.split(';').first);
      }

      text = _collapse(text);
      if (text.isEmpty) return WebSnippet(url: url, error: 'empty');
      if (text.length > maxChars) {
        text = '${text.substring(0, maxChars)}…';
      }
      return WebSnippet(url: url, title: title, text: text);
    } on TimeoutException {
      return WebSnippet(url: url, error: 'timeout');
    } catch (e) {
      return WebSnippet(url: url, error: e.toString());
    } finally {
      hc.close(force: true);
    }
  }

  // Some sites (anti-bot walls like Qrator) redirect to themselves and expect
  // the session cookie back on the next hop; package:http follows redirects
  // without forwarding cookies, so those sites loop forever. Follow redirects
  // by hand, carrying cookies along the chain.
  static Future<_FetchResult> _get(HttpClient hc, Uri start) async {
    var uri = start;
    final jar = <Cookie>[];
    for (var hop = 0; hop < 6; hop++) {
      final req = await hc.getUrl(uri);
      req.followRedirects = false;
      req.headers
        ..set(HttpHeaders.acceptHeader,
            'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8')
        ..set('Accept-Language', 'ru,en;q=0.8');
      req.cookies.addAll(jar);
      final res = await req.close();
      jar.addAll(res.cookies);
      final loc = res.headers.value(HttpHeaders.locationHeader);
      if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) {
        await res.drain<void>();
        uri = uri.resolve(loc);
        continue;
      }
      final bb = BytesBuilder(copy: false);
      await for (final chunk in res) {
        bb.add(chunk);
        if (bb.length > 3 << 20) break; // 3 MB is plenty for text
      }
      return _FetchResult(
        statusCode: res.statusCode,
        contentType: res.headers.value(HttpHeaders.contentTypeHeader) ?? '',
        bytes: bb.takeBytes(),
      );
    }
    return const _FetchResult(statusCode: 310, contentType: '', bytes: []);
  }

  static bool _looksHtml(String s) {
    final head = s.trimLeft();
    final probe =
        head.substring(0, head.length < 256 ? head.length : 256).toLowerCase();
    return probe.startsWith('<!doctype html') || probe.contains('<html');
  }

  static String _collapse(String s) {
    final out = StringBuffer();
    var blank = 0;
    for (final raw in s.split('\n')) {
      final line = raw.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ').trim();
      if (line.isEmpty) {
        if (++blank > 1) continue;
      } else {
        blank = 0;
      }
      out.writeln(line);
    }
    return out.toString().trim();
  }
}
