import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart-ext:angel_wings';

int bindWingsIPv4ServerSocket(Uint8List address, int port, bool shared,
    int backlog, bool v6Only, SendPort sendPort) native 'Dart_WingsSocket_bind';

int bindWingsIPv6ServerSocket(Uint8List address, int port, bool shared,
    int backlog, bool v6Only, SendPort sendPort) native 'Dart_WingsSocket_bind';

int getWingsServerSocketPort(int pointer) native 'Dart_WingsSocket_getPort';

void writeToNativeSocket(int fd, Uint8List data)
    native 'Dart_WingsSocket_write';

void closeNativeSocketDescriptor(int fd)
    native 'Dart_WingsSocket_closeDescriptor';

void closeWingsSocket(int pointer) native 'Dart_WingsSocket_close';

class WingsSocket extends Stream<int> {
  final StreamController<int> _ctrl = StreamController();
  final int _pointer;
  final RawReceivePort _recv;
  bool _open = true;
  int _port;

  WingsSocket._(this._pointer, this._recv) {
    _recv.handler = (h) {
      if (!_ctrl.isClosed) {
        _ctrl.add(h as int);
      }
    };
  }

  static Future<WingsSocket> bind(address, int port,
      {bool shared = false, int backlog = 0, bool v6Only = false}) async {
    var recv = RawReceivePort();
    int ptr;
    InternetAddress addr;

    if (address is InternetAddress) {
      addr = address;
    } else if (address is String) {
      var addrs = await InternetAddress.lookup(address);
      if (addrs.isNotEmpty) {
        addr = addrs[0];
      } else {
        throw StateError('Internet address lookup failed: $address');
      }
    } else {
      throw ArgumentError.value(
          address, 'address', 'must be an InternetAddress or String');
    }

    try {
      if (addr.type == InternetAddressType.IPv6) {
        ptr = bindWingsIPv6ServerSocket(Uint8List.fromList(addr.rawAddress),
            port, shared, backlog, v6Only, recv.sendPort);
      } else {
        ptr = bindWingsIPv4ServerSocket(Uint8List.fromList(addr.rawAddress),
            port, shared, backlog, v6Only, recv.sendPort);
      }

      return WingsSocket._(ptr, recv);
    } catch (e) {
      recv.close();
      rethrow;
    }
  }

  int get port => _port ??= getWingsServerSocketPort(_pointer);

  @override
  StreamSubscription<int> listen(void Function(int event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    return _ctrl.stream
        .listen(onData, onError: onError, cancelOnError: cancelOnError);
  }

  Future<void> close() async {
    if (_open) {
      _open = false;
      closeWingsSocket(_pointer);
      _recv.close();
      await _ctrl.close();
    }
  }
}