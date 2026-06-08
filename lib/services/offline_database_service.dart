import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/evidencia_local.dart';
import '../models/incidente_local.dart';

class OfflineDatabaseService {
  static final OfflineDatabaseService instance = OfflineDatabaseService._();
  static const _dbName = 'tallermovil_offline.db';
  static const _dbVersion = 2;

  Database? _db;

  OfflineDatabaseService._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _crearTablas,
      onUpgrade: _migrar,
    );
    return _db!;
  }

  Future<void> _crearTablas(Database db, int version) async {
    // CU-OFF-04: Almacenamiento local SQLite para incidentes offline.
    await db.execute('''
      CREATE TABLE incidente_local (
        id_local TEXT PRIMARY KEY,
        id_backend INTEGER,
        cliente_id TEXT NOT NULL,
        vehiculo_id INTEGER NOT NULL,
        categoria_id INTEGER NOT NULL,
        prioridad_id INTEGER NOT NULL,
        descripcion TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        fecha_creacion_local TEXT NOT NULL,
        fecha_reporte TEXT NOT NULL,
        estado_local TEXT NOT NULL,
        estado_sincronizacion TEXT NOT NULL,
        version_local INTEGER NOT NULL,
        ultimo_error TEXT,
        id_conflicto INTEGER,
        cotizacion_express INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // CU-OFF-05: Evidencias locales pendientes; los archivos no se borran aqui.
    await db.execute('''
      CREATE TABLE evidencia_local (
        id_local TEXT PRIMARY KEY,
        incidente_local_id TEXT NOT NULL,
        id_backend INTEGER,
        tipo_evidencia TEXT NOT NULL,
        ruta_archivo_local TEXT,
        texto TEXT,
        estado_sincronizacion TEXT NOT NULL,
        ultimo_error TEXT,
        FOREIGN KEY (incidente_local_id)
          REFERENCES incidente_local (id_local)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrar(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _agregarColumna(
        db,
        'incidente_local',
        'fecha_reporte',
        'TEXT',
        defaultExpression: 'fecha_creacion_local',
      );
      await _agregarColumna(db, 'incidente_local', 'id_conflicto', 'INTEGER');
      await _agregarColumna(db, 'evidencia_local', 'id_backend', 'INTEGER');
      await _agregarColumna(db, 'evidencia_local', 'texto', 'TEXT');
      await db.execute('''
        UPDATE evidencia_local
        SET texto = contenido_texto
        WHERE texto IS NULL
      ''').catchError((_) {});
    }
  }

  Future<void> _agregarColumna(
    Database db,
    String tabla,
    String columna,
    String tipo, {
    String? defaultExpression,
  }) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    final existe = info.any((row) => row['name'] == columna);
    if (existe) return;

    await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $tipo');
    if (defaultExpression != null) {
      await db.execute('UPDATE $tabla SET $columna = $defaultExpression');
    }
  }

  Future<String> generarIdLocal() async {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'OFF-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> guardarIncidente({
    required IncidenteLocal incidente,
    List<File> imagenes = const [],
    List<File> audios = const [],
    String texto = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // CU-OFF-06: Guardar incidente con estado REGISTRADO_LOCAL/PENDIENTE.
      await txn.insert(
        'incidente_local',
        incidente.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (var i = 0; i < imagenes.length; i++) {
        final ruta = await _copiarEvidencia(
          imagenes[i],
          incidente.idLocal,
          'imagen_$i',
        );
        await txn.insert(
          'evidencia_local',
          EvidenciaLocal(
            idLocal: '${incidente.idLocal}-IMG-$i',
            incidenteLocalId: incidente.idLocal,
            tipoEvidencia: EvidenciaLocal.tipoImagen,
            rutaArchivoLocal: ruta,
            estadoSincronizacion: IncidenteLocal.estadoSyncPendiente,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (var i = 0; i < audios.length; i++) {
        final ruta = await _copiarEvidencia(
          audios[i],
          incidente.idLocal,
          'audio_$i',
        );
        await txn.insert(
          'evidencia_local',
          EvidenciaLocal(
            idLocal: '${incidente.idLocal}-AUD-$i',
            incidenteLocalId: incidente.idLocal,
            tipoEvidencia: EvidenciaLocal.tipoAudio,
            rutaArchivoLocal: ruta,
            estadoSincronizacion: IncidenteLocal.estadoSyncPendiente,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (texto.trim().isNotEmpty) {
        await txn.insert(
          'evidencia_local',
          EvidenciaLocal(
            idLocal: '${incidente.idLocal}-TXT-0',
            incidenteLocalId: incidente.idLocal,
            tipoEvidencia: EvidenciaLocal.tipoTexto,
            texto: texto.trim(),
            estadoSincronizacion: IncidenteLocal.estadoSyncPendiente,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<String> _copiarEvidencia(
    File archivo,
    String incidenteLocalId,
    String prefijo,
  ) async {
    // CU-OFF-07: Copiar evidencias a almacenamiento de la app hasta confirmar backend.
    final dir = await getApplicationDocumentsDirectory();
    final evidenciaDir = Directory(
      p.join(dir.path, 'offline_evidencias', incidenteLocalId),
    );
    if (!await evidenciaDir.exists()) {
      await evidenciaDir.create(recursive: true);
    }

    final extension = p.extension(archivo.path);
    final destino = File(
      p.join(
        evidenciaDir.path,
        '${prefijo}_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    return (await archivo.copy(destino.path)).path;
  }

  Future<List<IncidenteLocal>> listarPendientes() async {
    final db = await database;
    final rows = await db.query(
      'incidente_local',
      where: 'estado_sincronizacion != ?',
      whereArgs: [IncidenteLocal.estadoSyncSincronizado],
      orderBy: 'fecha_creacion_local DESC',
    );
    return rows.map(IncidenteLocal.fromMap).toList();
  }

  Future<List<IncidenteLocal>> listarParaSincronizar() async {
    final db = await database;
    final rows = await db.query(
      'incidente_local',
      where: 'estado_sincronizacion IN (?, ?, ?)',
      whereArgs: [
        IncidenteLocal.estadoSyncPendiente,
        IncidenteLocal.estadoSyncError,
        IncidenteLocal.estadoSyncParcial,
      ],
      orderBy: 'fecha_creacion_local ASC',
    );
    return rows.map(IncidenteLocal.fromMap).toList();
  }

  Future<List<IncidenteLocal>> listarPorEstado(String estado) async {
    final db = await database;
    final rows = await db.query(
      'incidente_local',
      where: 'estado_sincronizacion = ?',
      whereArgs: [estado],
      orderBy: 'fecha_creacion_local DESC',
    );
    return rows.map(IncidenteLocal.fromMap).toList();
  }

  Future<List<EvidenciaLocal>> listarEvidenciasPendientes(
    String incidenteLocalId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'evidencia_local',
      where: 'incidente_local_id = ? AND estado_sincronizacion != ?',
      whereArgs: [incidenteLocalId, IncidenteLocal.estadoSyncSincronizado],
      orderBy: 'id_local ASC',
    );
    return rows.map(EvidenciaLocal.fromMap).toList();
  }

  Future<int> contarPendientes() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM incidente_local '
      'WHERE estado_sincronizacion != ?',
      [IncidenteLocal.estadoSyncSincronizado],
    );
    return int.tryParse(rows.first['total'].toString()) ?? 0;
  }

  Future<void> actualizarIncidente(
    String idLocal, {
    int? idBackend,
    int? idConflicto,
    bool limpiarConflicto = false,
    String? estadoSincronizacion,
    String? ultimoError,
  }) async {
    final db = await database;
    final values = <String, Object?>{};
    if (idBackend != null) values['id_backend'] = idBackend;
    if (idConflicto != null) values['id_conflicto'] = idConflicto;
    if (limpiarConflicto) values['id_conflicto'] = null;
    if (estadoSincronizacion != null) {
      values['estado_sincronizacion'] = estadoSincronizacion;
    }
    values['ultimo_error'] = ultimoError;
    await db.update(
      'incidente_local',
      values,
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<IncidenteLocal?> obtenerIncidentePorConflicto(int idConflicto) async {
    final db = await database;
    final rows = await db.query(
      'incidente_local',
      where: 'id_conflicto = ?',
      whereArgs: [idConflicto],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IncidenteLocal.fromMap(rows.first);
  }

  Future<void> actualizarEvidencia(
    String idLocal, {
    int? idBackend,
    required String estadoSincronizacion,
    String? ultimoError,
  }) async {
    final db = await database;
    await db.update(
      'evidencia_local',
      {
        'id_backend': idBackend,
        'estado_sincronizacion': estadoSincronizacion,
        'ultimo_error': ultimoError,
      },
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<void> actualizarEvidenciasPorIncidente(
    String incidenteLocalId, {
    int? idBackend,
    required String estadoSincronizacion,
    String? ultimoError,
  }) async {
    final db = await database;
    await db.update(
      'evidencia_local',
      {
        'id_backend': idBackend,
        'estado_sincronizacion': estadoSincronizacion,
        'ultimo_error': ultimoError,
      },
      where: 'incidente_local_id = ?',
      whereArgs: [incidenteLocalId],
    );
  }
}
