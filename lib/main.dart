import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/datasources/anilist_remote_datasource.dart';
import 'data/datasources/jikan_remote_datasource.dart';
import 'data/datasources/kitsu_remote_datasource.dart';
import 'data/datasources/local_storage_datasource.dart';
import 'data/repositories/anime_repository_impl.dart';
import 'kokuro/app_strings.dart';
import 'kokuro/app_router.dart';
import 'kokuro/kokuro_bloc.dart';
import 'kokuro/kokuro_theme.dart';
import 'kokuro/tokens.dart';
import 'kokuro/image_diag.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await K.restoreAccent();
  runApp(const KokuroApp());
}

class KokuroApp extends StatefulWidget {
  const KokuroApp({super.key});

  @override
  State<KokuroApp> createState() => _KokuroAppState();
}

class _KokuroAppState extends State<KokuroApp> {
  late final AnimeRepositoryImpl _repository;
  late final KokuroBloc _kokuroBloc;

  @override
  void initState() {
    super.initState();
    _repository = AnimeRepositoryImpl(
      jikan: JikanRemoteDataSource(),
      kitsu: KitsuRemoteDataSource(),
      anilist: AniListRemoteDataSource(),
      local: LocalStorageDataSource(),
    );
    _kokuroBloc = KokuroBloc(repo: _repository);
  }

  @override
  void dispose() {
    _kokuroBloc.close();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _kokuroBloc,
      child: ValueListenableBuilder<int>(
        valueListenable: K.accentVersion,
        builder: (_, _, _) {
          return MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: KokuroTheme.dark,
            routerConfig: appRouter,
            locale: const Locale('ar', 'EG'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
            builder: (context, child) => Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const ImageDiagOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }
}
