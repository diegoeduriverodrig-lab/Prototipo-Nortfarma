import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'services/admin_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/carrito_local_service.dart';
import 'services/catalogo_service.dart';
import 'services/culqi_service.dart';
import 'services/imagen_service.dart';
import 'services/pedido_service.dart';
import 'services/perfil_service.dart';
import 'services/seguimiento_service.dart';
import 'viewmodels/carrito_viewmodel.dart';
import 'viewmodels/navegacion_cliente_viewmodel.dart';
import 'viewmodels/sesion_viewmodel.dart';
import 'views/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NortfarmaApp());
}

class NortfarmaApp extends StatelessWidget {
  const NortfarmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => ApiService()),
        Provider(create: (context) => PerfilService(context.read<ApiService>())),
        Provider(create: (context) => CatalogoService(context.read<ApiService>())),
        Provider(create: (context) => PedidoService(context.read<ApiService>())),
        Provider(create: (_) => ImagenService()),
        Provider(create: (_) => CulqiService()),
        Provider(create: (context) => SeguimientoService(context.read<ApiService>())),
        Provider(create: (context) => AdminService(context.read<ApiService>())),
        ChangeNotifierProvider(
          create: (context) => SesionViewModel(
            context.read<AuthService>(),
            context.read<PerfilService>(),
          ),
        ),
        // El carrito sigue al usuario con sesión: cada usuario tiene el suyo.
        ChangeNotifierProxyProvider<SesionViewModel, CarritoViewModel>(
          create: (_) => CarritoViewModel(CarritoLocalService()),
          update: (_, sesion, carrito) => carrito!..usarUsuario(sesion.usuario?.uid),
        ),
        ChangeNotifierProvider(create: (_) => NavegacionClienteViewModel()),
      ],
      child: MaterialApp(
        title: 'Boticas Felicidad',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.claro,
        home: const SplashView(),
      ),
    );
  }
}
