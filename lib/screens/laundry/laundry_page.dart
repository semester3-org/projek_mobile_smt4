import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/repositories/laundry_repository.dart';
import '../../models/laundry_place.dart';
import '../../widgets/cards/laundry_card.dart';

/// Daftar laundry terdekat — data dari API.
class LaundryPage extends StatefulWidget {
  const LaundryPage({super.key});

  @override
  State<LaundryPage> createState() => _LaundryPageState();
}

class _LaundryPageState extends State<LaundryPage> {
  List<LaundryPlace> _list = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });

    final result = await LaundryRepository.getAll();
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
      appBar: AppBar(title: const Text('Laundry terdekat')),
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
        Center(child: Text('Belum ada data laundry.',
            style: TextStyle(color: Colors.grey.shade600))),
      ]);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final place = _list[i];
        return LaundryCard(
          place: place,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Detail: ${place.name}')),
            );
          },
        );
      },
    );
  }
}