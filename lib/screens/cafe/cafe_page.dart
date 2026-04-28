import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/repositories/cafe_repository.dart';
import '../../models/cafe_place.dart';
import '../../widgets/cards/cafe_card.dart';

/// Daftar kafe: foto, rating, suasana — data dari API.
class CafePage extends StatefulWidget {
  const CafePage({super.key});

  @override
  State<CafePage> createState() => _CafePageState();
}

class _CafePageState extends State<CafePage> {
  List<CafePlace> _list = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });

    final result = await CafeRepository.getAll();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() { _list = result.data!; _isLoading = false; });
    } else {
      setState(() { _error = result.error; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      appBar: AppBar(title: const Text('Kafe di sekitar')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ]),
        ),
      );
    }

    if (_list.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.35),
        Center(child: Text('Belum ada data kafe.',
            style: TextStyle(color: Colors.grey.shade600))),
      ]);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final cafe = _list[i];
        return CafeCard(
          cafe: cafe,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${cafe.name} — ${cafe.vibe}')),
            );
          },
        );
      },
    );
  }
}