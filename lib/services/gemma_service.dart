import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';

class GemmaChatService {
	GemmaChatService._();

	static final GemmaChatService instance = GemmaChatService._();

	static const _modelUrl =
			'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

	bool _ready = false;
	dynamic _model;
	dynamic _session;

	Future<void> initialize() async {
		if (_ready) {
			return;
		}

		await FlutterGemma.installModel(
			modelType: ModelType.gemmaIt,
			fileType: ModelFileType.litertlm,
		).fromNetwork(_modelUrl).install();

		_model = await FlutterGemma.getActiveModel(
			maxTokens: 4096,
			preferredBackend: PreferredBackend.gpu,
			supportImage: true,
			supportAudio: false,
		);

		_session = await _model.createSession(
			temperature: 0.7,
			topK: 1,
		);

		_ready = true;
	}

	Stream<String> sendMessage(String text) async* {
		if (!_ready) {
			await initialize();
		}

		await _session.addQueryChunk(
			Message(text: text, isUser: true),
		);

		await for (final chunk in _session.getResponseAsync()) {
			yield chunk.toString();
		}
	}

	Future<void> dispose() async {
		if (_session != null) {
			await _session.close();
		}
		_ready = false;
	}
}
