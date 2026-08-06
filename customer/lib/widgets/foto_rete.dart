import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Sostituto 1:1 di Image.network con CACHE SU DISCO.
///
/// Image.network tiene le immagini solo in memoria: a ogni riavvio
/// dell'app tutte le foto (menu, card ristoranti, giochi) venivano
/// riscaricate da Firebase Storage, che ha ~1s di latenza anche per una
/// thumbnail da 13KB. Con la cache persistente il primo caricamento
/// resta quello, ma da li' in poi la foto e' istantanea.
///
/// Stessa firma dei parametri usati nel progetto: la migrazione dei
/// call-site e' un rename, i builder restano identici.
class FotoRete extends StatelessWidget {
  final String src;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final FilterQuality filterQuality;

  const FotoRete(
    this.src, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
    this.loadingBuilder,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  Widget build(BuildContext context) {
    // NetworkImage con URL vuoto lancerebbe in fase di risoluzione:
    // qui si delega direttamente all'errorBuilder del chiamante.
    if (src.isEmpty) {
      return errorBuilder?.call(
            context,
            ArgumentError('URL immagine vuoto'),
            null,
          ) ??
          SizedBox(width: width, height: height);
    }

    return Image(
      image: CachedNetworkImageProvider(src),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      filterQuality: filterQuality,
      gaplessPlayback: true,
    );
  }
}
