enum Role { user, assistant, system }

class Attachment {
  final String path;
  final String mime;
  final String base64; // data without prefix
  const Attachment({required this.path, required this.mime, required this.base64});

  String get dataUri => 'data:$mime;base64,$base64';
}

/// A web page fetched for the model when Browser (beta) is on. The cleaned
/// text goes to the API invisibly; the chat only shows a small chip.
class WebSnippet {
  final String url;
  final String title;
  final String text;
  final String? error;
  const WebSnippet(
      {required this.url, this.title = '', this.text = '', this.error});

  bool get ok => error == null;
  String get host => Uri.tryParse(url)?.host ?? url;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'text': text,
        if (error != null) 'error': error,
      };

  factory WebSnippet.fromJson(Map<String, dynamic> j) => WebSnippet(
        url: j['url'] ?? '',
        title: j['title'] ?? '',
        text: j['text'] ?? '',
        error: j['error'],
      );
}

class ChatMessage {
  final Role role;
  String text;
  String reasoning; // streamed "thinking" content, shown collapsed
  final List<Attachment> images;
  final List<WebSnippet> web;
  bool webLoading;
  bool streaming;
  String? error;
  final DateTime at;

  // ---- side-by-side comparison (two models answering one prompt) ----
  bool compare;
  String modelA;
  String modelB;
  String altText;
  String altReasoning;
  bool altStreaming;
  String? altError;

  ChatMessage({
    required this.role,
    this.text = '',
    this.reasoning = '',
    List<Attachment>? images,
    List<WebSnippet>? web,
    this.webLoading = false,
    this.streaming = false,
    this.error,
    DateTime? at,
    this.compare = false,
    this.modelA = '',
    this.modelB = '',
    this.altText = '',
    this.altReasoning = '',
    this.altStreaming = false,
    this.altError,
  })  : images = images ?? [],
        web = web ?? [],
        at = at ?? DateTime.now();

  bool get hasReasoning => reasoning.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'reasoning': reasoning,
        'at': at.toIso8601String(),
        'images': images.map((a) => {'mime': a.mime, 'b64': a.base64}).toList(),
        'web': web.map((w) => w.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: Role.values.firstWhere((r) => r.name == j['role'],
            orElse: () => Role.user),
        text: j['text'] ?? '',
        reasoning: j['reasoning'] ?? '',
        at: DateTime.tryParse(j['at'] ?? '') ?? DateTime.now(),
        images: ((j['images'] as List?) ?? [])
            .map((e) => Attachment(
                path: '', mime: e['mime'] ?? 'image/png', base64: e['b64'] ?? ''))
            .toList(),
        web: ((j['web'] as List?) ?? [])
            .map((e) => WebSnippet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    this.title = '',
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  // Persisted without image bytes to keep stored history light.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) {
          final j = m.toJson();
          j['images'] = [];
          return j;
        }).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'],
        title: j['title'] ?? '',
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? ''),
        messages: ((j['messages'] as List?) ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GenerationConfig {
  double temperature;
  int maxTokens;
  String systemPrompt;
  bool stream;

  GenerationConfig({
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.systemPrompt = '',
    this.stream = true,
  });
}
