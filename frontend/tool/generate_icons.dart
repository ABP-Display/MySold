import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final source = img.decodePng(
    File('assets/icons/logo.png').readAsBytesSync(),
  )!;
  for (final size in [192, 512]) {
    File('web/icons/Icon-$size.png').writeAsBytesSync(
      img.encodePng(img.copyResize(source, width: size, height: size)),
    );
    final padded = img.Image(size, size);
    img.fill(padded, img.getColor(0, 0, 0, 255));
    final inner = (size * .8).round();
    final offset = ((size - inner) / 2).round();
    img.copyInto(
      padded,
      img.copyResize(source, width: inner, height: inner),
      dstX: offset,
      dstY: offset,
    );
    File(
      'web/icons/Icon-maskable-$size.png',
    ).writeAsBytesSync(img.encodePng(padded));
  }
  File('web/favicon.png').writeAsBytesSync(
    img.encodePng(img.copyResize(source, width: 64, height: 64)),
  );
}
