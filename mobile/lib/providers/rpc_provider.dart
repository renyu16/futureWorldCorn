import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rpc_service.dart';
import '../contracts/addresses.dart' as addr;

@immutable
class RpcState {
  final String url;
  final bool isLoading;
  final String? error;

  const RpcState({required this.url, this.isLoading = false, this.error});

  RpcState copyWith({String? url, bool? isLoading, String? error}) =>
      RpcState(url: url ?? this.url, isLoading: isLoading ?? this.isLoading, error: error);
}

class RpcNotifier extends StateNotifier<RpcState> {
  RpcNotifier() : super(const RpcState(url: addr.defaultRpcUrl)) {
    _init();
  }

  Future<void> _init() async {
    await RpcService.init();
    state = RpcState(url: RpcService.rpcUrl);
  }

  Future<bool> saveRpcUrl(String url) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await RpcService.setRpcUrl(url);
      state = RpcState(url: RpcService.rpcUrl);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '保存失败: $e');
      return false;
    }
  }

  Future<bool> testConnection(String rpcUrl) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uri = Uri.parse(rpcUrl);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write('{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}');
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(const Utf8Decoder()).join();
      client.close(force: false);
      state = state.copyWith(isLoading: false);
      return body.contains('"result"');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '连接失败: $e');
      return false;
    }
  }

  Future<void> restoreDefault() async {
    await RpcService.setRpcUrl('');
    state = const RpcState(url: addr.defaultRpcUrl);
  }
}

final rpcProvider = StateNotifierProvider<RpcNotifier, RpcState>((ref) {
  return RpcNotifier();
});

final rpcUrlProvider = Provider<String>((ref) {
  return ref.watch(rpcProvider).url;
});
