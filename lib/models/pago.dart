class ResumenCobro {
  final int idCobro;
  final int idIncidente;
  final int idAsignacion;
  final String estadoPago;
  final double subtotal;
  final double descuento;
  final double total;
  final DateTime? fechaGeneracion;
  final DateTime? fechaAceptacion;
  final DateTime? fechaPago;
  final DateTime? fechaComprobante;
  final List<ConceptoCobro> conceptos;

  ResumenCobro({
    required this.idCobro,
    required this.idIncidente,
    required this.idAsignacion,
    required this.estadoPago,
    required this.subtotal,
    required this.descuento,
    required this.total,
    this.fechaGeneracion,
    this.fechaAceptacion,
    this.fechaPago,
    this.fechaComprobante,
    required this.conceptos,
  });

  factory ResumenCobro.fromJson(Map<String, dynamic> json) {
    return ResumenCobro(
      idCobro: _toInt(json['id_cobro']),
      idIncidente: _toInt(json['id_incidente']),
      idAsignacion: _toInt(json['id_asignacion']),
      estadoPago: json['estado_pago']?.toString() ?? 'SIN_ESTADO',
      subtotal: _toDouble(json['subtotal']),
      descuento: _toDouble(json['descuento']),
      total: _toDouble(json['total']),
      fechaGeneracion:
          DateTime.tryParse(json['fecha_generacion']?.toString() ?? ''),
      fechaAceptacion:
          DateTime.tryParse(json['fecha_aceptacion']?.toString() ?? ''),
      fechaPago: DateTime.tryParse(json['fecha_pago']?.toString() ?? ''),
      fechaComprobante:
          DateTime.tryParse(json['fecha_comprobante']?.toString() ?? ''),
      conceptos: (json['conceptos'] as List? ?? [])
          .map((e) => ConceptoCobro.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ConceptoCobro {
  final int id;
  final int idConcepto;
  final String descripcion;
  final String tipo;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String observacion;

  ConceptoCobro({
    required this.id,
    required this.idConcepto,
    required this.descripcion,
    required this.tipo,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.observacion,
  });

  factory ConceptoCobro.fromJson(Map<String, dynamic> json) {
    return ConceptoCobro(
      id: _toInt(json['id']),
      idConcepto: _toInt(json['id_concepto']),
      descripcion: json['descripcion']?.toString() ?? 'Concepto',
      tipo: json['tipo']?.toString() ?? '',
      cantidad: _toDouble(json['cantidad']),
      precioUnitario: _toDouble(json['precio_unitario']),
      subtotal: _toDouble(json['subtotal']),
      observacion: json['observacion']?.toString() ?? '',
    );
  }
}

class PagoRegistrado {
  final int idPago;
  final String metodoPago;
  final String referenciaPago;
  final double montoPagado;
  final String estadoPago;
  final DateTime? fechaPago;

  PagoRegistrado({
    required this.idPago,
    required this.metodoPago,
    required this.referenciaPago,
    required this.montoPagado,
    required this.estadoPago,
    this.fechaPago,
  });

  factory PagoRegistrado.fromJson(Map<String, dynamic> json) {
    return PagoRegistrado(
      idPago: _toInt(json['id_pago']),
      metodoPago: json['metodo_pago']?.toString() ?? '',
      referenciaPago: json['referencia_pago']?.toString() ?? '',
      montoPagado: _toDouble(json['monto_pagado']),
      estadoPago: json['estado_pago']?.toString() ?? '',
      fechaPago: DateTime.tryParse(json['fecha_pago']?.toString() ?? ''),
    );
  }
}

class ComprobantePago {
  final int idComprobante;
  final int idCobro;
  final String numeroComprobante;
  final DateTime? fechaEmision;
  final double total;
  final ResumenCobro? detalle;

  ComprobantePago({
    required this.idComprobante,
    required this.idCobro,
    required this.numeroComprobante,
    this.fechaEmision,
    required this.total,
    this.detalle,
  });

  factory ComprobantePago.fromJson(Map<String, dynamic> json) {
    final detalleJson = json['detalle'];
    return ComprobantePago(
      idComprobante: _toInt(json['id_comprobante']),
      idCobro: _toInt(json['id_cobro']),
      numeroComprobante:
          json['numero_comprobante']?.toString() ?? 'Sin numero',
      fechaEmision: DateTime.tryParse(json['fecha_emision']?.toString() ?? ''),
      total: _toDouble(json['total']),
      detalle: detalleJson is Map
          ? ResumenCobro.fromJson(Map<String, dynamic>.from(detalleJson))
          : null,
    );
  }
}

class PagoConComprobante {
  final String mensaje;
  final PagoRegistrado pago;
  final ComprobantePago comprobante;

  PagoConComprobante({
    required this.mensaje,
    required this.pago,
    required this.comprobante,
  });

  factory PagoConComprobante.fromJson(Map<String, dynamic> json) {
    return PagoConComprobante(
      mensaje: json['mensaje']?.toString() ?? 'Pago registrado',
      pago: PagoRegistrado.fromJson(
        Map<String, dynamic>.from(json['pago'] as Map? ?? {}),
      ),
      comprobante: ComprobantePago.fromJson(
        Map<String, dynamic>.from(json['comprobante'] as Map? ?? {}),
      ),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
