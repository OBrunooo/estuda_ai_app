import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/api_exception.dart';
import '../core/network/pending_tema_generation_storage.dart';
import '../models/loading_questoes_args.dart';
import '../models/tema_resumo_model.dart';
import '../app/tema_geracao_notifier.dart';
import '../repositories/tema_repository.dart';
import '../services/tema_study_service.dart';
import '../widgets/profile_app_bar_button.dart';

/// Tela inicial após login: lista temas do usuário ([GET /temas]) e acesso a novo tema.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TemaResumoModel>? _temas;
  bool _loading = true;
  String? _error;
  PendingTemaGenerationState? _geracaoPendente;
  late final TemaGeracaoNotifier _geracaoNotifier;

  @override
  void initState() {
    super.initState();
    _geracaoNotifier = context.read<TemaGeracaoNotifier>();
    _geracaoNotifier.addListener(_onGeracaoEmSegundoPlano);
    _carregar();
    _atualizarGeracaoPendente();
  }

  @override
  void dispose() {
    _geracaoNotifier.removeListener(_onGeracaoEmSegundoPlano);
    super.dispose();
  }

  void _onGeracaoEmSegundoPlano() {
    if (!mounted) return;
    _carregar();
    _atualizarGeracaoPendente();
  }

  Future<void> _atualizarGeracaoPendente() async {
    final svc = context.read<TemaStudyService>();
    final p = await svc.lerGeracaoPendente();
    if (mounted) {
      setState(() => _geracaoPendente = p);
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<TemaRepository>();
      final lista = await repo.listarTemas();
      if (!mounted) return;
      setState(() {
        _temas = lista;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _abrirTema(TemaResumoModel t) {
    context.push(
      '/loading',
      extra: LoadingQuestoesArgs.existente(temaId: t.temaId, temaNome: t.tema),
    );
  }

  void _continuarGeracao() {
    context.read<TemaStudyService>().retomarGeracaoEmSegundoPlano();
    if (mounted) setState(() {});
  }

  Future<void> _descartarGeracao() async {
    await context.read<TemaStudyService>().descartarGeracaoPendente();
    if (mounted) setState(() => _geracaoPendente = null);
  }

  Widget _cardGeracaoPendente(PendingTemaGenerationState p) {
    final scheme = Theme.of(context).colorScheme;
    final ativo = context.read<TemaStudyService>().geracaoAtiva;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (ativo)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                else
                  Icon(Icons.hourglass_top_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ativo ? 'Gerando questões…' : 'Geração pendente',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tema: "${p.temaDigitado}"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: ativo ? null : _continuarGeracao,
                    child: Text(ativo ? 'Aguardando…' : 'Continuar geração'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: ativo ? null : _descartarGeracao,
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seus temas'),
        actions: const [ProfileAppBarButton()],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/novo-tema'),
        icon: const Icon(Icons.add),
        label: const Text('Novo tema'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _carregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final temas = _temas ?? [];
    final pendente = _geracaoPendente;

    if (temas.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _carregar();
          await _atualizarGeracaoPendente();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            if (pendente != null) ...[
              _cardGeracaoPendente(pendente),
              const SizedBox(height: 16),
            ],
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum tema ainda',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie um tema para a API gerar ou buscar questões.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push('/novo-tema'),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar tema'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _carregar();
        await _atualizarGeracaoPendente();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: temas.length + (pendente != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (pendente != null && i == 0) {
            return _cardGeracaoPendente(pendente);
          }
          final idx = pendente != null ? i - 1 : i;
          final t = temas[idx];
          final concluido = t.concluido;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  concluido ? Icons.check : Icons.school_outlined,
                ),
              ),
              title: Text(
                t.tema,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                concluido
                    ? 'Concluído'
                    : 'Em andamento • ${t.conclusao}%',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrirTema(t),
            ),
          );
        },
      ),
    );
  }
}
