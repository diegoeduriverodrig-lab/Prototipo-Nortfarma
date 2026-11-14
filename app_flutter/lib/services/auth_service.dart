import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/usuario.dart';

/// Error de autenticación con un mensaje listo para mostrar al usuario.
class AuthException implements Exception {
  const AuthException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Único punto de la app que habla con Firebase Authentication.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance {
    // Correos de Firebase (recuperar contraseña) en español.
    _auth.setLanguageCode('es');
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _googleInicializado;

  Stream<CuentaFirebase?> get cambiosDeSesion =>
      _auth.authStateChanges().map((u) => u == null ? null : _aCuenta(u));

  CuentaFirebase? get cuentaActual {
    final u = _auth.currentUser;
    return u == null ? null : _aCuenta(u);
  }

  Future<void> iniciarSesion(String correo, String contrasena) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensajeDe(e));
    }
  }

  /// Crea la cuenta en Firebase. El perfil (DNI, celular, rol) lo guarda PerfilService.
  Future<void> crearCuenta(String correo, String contrasena, String nombreVisible) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: contrasena,
      );
      await cred.user?.updateDisplayName(nombreVisible.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensajeDe(e));
    }
  }

  Future<void> enviarRecuperacion(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensajeDe(e));
    }
  }

  /// Devuelve false si el usuario cerró la ventana de Google sin elegir cuenta.
  Future<bool> iniciarConGoogle() async {
    try {
      await (_googleInicializado ??= _google.initialize());
      final cuenta = await _google.authenticate();
      final idToken = cuenta.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('Google no devolvió credenciales. Intenta de nuevo.');
      }
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthException('No se pudo iniciar sesión con Google (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mensajeDe(e));
    }
  }

  Future<void> cerrarSesion() async {
    if (_googleInicializado != null) await _google.signOut();
    await _auth.signOut();
  }

  CuentaFirebase _aCuenta(User u) =>
      CuentaFirebase(uid: u.uid, correo: u.email ?? '', nombreVisible: u.displayName);

  String _mensajeDe(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red.';
      case 'account-exists-with-different-credential':
        return 'Este correo ya está registrado con otro método de acceso.';
      default:
        return 'Ocurrió un error (${e.code}). Inténtalo de nuevo.';
    }
  }
}
