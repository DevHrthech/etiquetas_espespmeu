import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Envia dados crus (RAW) direto para o spooler de impressão do Windows,
/// sem passar pelo driver GDI. É assim que o ZPL chega intacto na GK888t.
///
/// Só funciona em Windows (usa a API Win32 do spooler via FFI).
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  /// Lista os nomes das impressoras instaladas no Windows.
  List<String> listPrinters() {
    final names = <String>[];
    final flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;

    final pcbNeeded = calloc<DWORD>();
    final pcReturned = calloc<DWORD>();
    try {
      EnumPrinters(flags, nullptr, 2, nullptr, 0, pcbNeeded, pcReturned);
      final bufferSize = pcbNeeded.value;
      if (bufferSize == 0) return names;

      final buffer = calloc<BYTE>(bufferSize);
      try {
        final ok = EnumPrinters(
          flags,
          nullptr,
          2,
          buffer.cast<Uint8>(),
          bufferSize,
          pcbNeeded,
          pcReturned,
        );
        if (ok == 0) return names;

        final count = pcReturned.value;
        final infoArray = buffer.cast<PRINTER_INFO_2>();
        for (var i = 0; i < count; i++) {
          final info = (infoArray + i).ref;
          if (info.pPrinterName != nullptr) {
            names.add(info.pPrinterName.toDartString());
          }
        }
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
    }
    return names;
  }

  /// Envia [zpl] como dados RAW para a impressora [printerName].
  void printRaw(String printerName, String zpl) {
    final phPrinter = calloc<HANDLE>();
    final printerNamePtr = printerName.toNativeUtf16();
    try {
      final opened = OpenPrinter(printerNamePtr, phPrinter, nullptr);
      if (opened == 0) {
        throw PrinterException('Não foi possível abrir a impressora "$printerName".');
      }
      final hPrinter = phPrinter.value;

      final docNamePtr = 'Etiquetas Bling'.toNativeUtf16();
      final dataTypePtr = 'RAW'.toNativeUtf16();
      final docInfo = calloc<DOC_INFO_1>();
      docInfo.ref.pDocName = docNamePtr;
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = dataTypePtr;

      try {
        final jobId = StartDocPrinter(hPrinter, 1, docInfo);
        if (jobId == 0) {
          throw PrinterException('Falha ao iniciar o trabalho de impressão.');
        }
        try {
          if (StartPagePrinter(hPrinter) == 0) {
            throw PrinterException('Falha ao iniciar a página de impressão.');
          }
          try {
            final bytes = latin1.encode(zpl);
            final dataPtr = calloc<Uint8>(bytes.length);
            try {
              dataPtr.asTypedList(bytes.length).setAll(0, bytes);
              final written = calloc<DWORD>();
              try {
                final ok = WritePrinter(hPrinter, dataPtr.cast<Void>(), bytes.length, written);
                if (ok == 0 || written.value != bytes.length) {
                  throw PrinterException('Falha ao enviar os dados para a impressora.');
                }
              } finally {
                calloc.free(written);
              }
            } finally {
              calloc.free(dataPtr);
            }
          } finally {
            EndPagePrinter(hPrinter);
          }
        } finally {
          EndDocPrinter(hPrinter);
        }
      } finally {
        calloc.free(docInfo);
        calloc.free(docNamePtr);
        calloc.free(dataTypePtr);
      }

      ClosePrinter(hPrinter);
    } finally {
      calloc.free(phPrinter);
      calloc.free(printerNamePtr);
    }
  }
}

class PrinterException implements Exception {
  final String message;
  PrinterException(this.message);
  @override
  String toString() => 'PrinterException: $message';
}
