import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/chat.dart';

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
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Mobile) ArcadeAI/1.2 (like wget)',
        'Accept':
            'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ru,en;q=0.8',
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) {
        return WebSnippet(url: url, error: 'HTTP ${res.statusCode}');
      }

      // The http package falls back to latin1 without a charset header, which
      // garbles Cyrillic — prefer a UTF-8 decode of the raw bytes.
      String body;
      try {
        body = utf8.decode(res.bodyBytes);
      } catch (_) {
        body = res.body;
      }

      final type = (res.headers['content-type'] ?? '').toLowerCase();
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
    }
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
