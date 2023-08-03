import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:push_app/domain/entities/push_message.dart';
import 'package:push_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationsBloc() : super(const NotificationsState()) {
    on<NotificationStatusChanged>(_notificationStatusChanged);
    on<NotificationsRecivied>(_onPushMessageRecivied);

    //Verificar estado de las notificaciones:
    _initialStatusCheck();

    //Listener para notificaciones en segundo plano:
    _onForegroundMessage();
  }

  static Future<void> initializedFCM() async {
    //Firebase Cloud Messaging
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  void _notificationStatusChanged(
      NotificationStatusChanged event, Emitter<NotificationsState> emit) {
    emit(state.copyWith(status: event.status));

    _getFCMToken();
  }

  void _onPushMessageRecivied(
      NotificationsRecivied event, Emitter<NotificationsState> emit) {
    emit(state.copyWith(notifications: [ event.pMessage, ...state.notifications ]));
  }

  void _initialStatusCheck() async {
    final settings = await messaging.getNotificationSettings();
    add(NotificationStatusChanged(settings.authorizationStatus));
  }

  void _getFCMToken() async {
    final settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    final token = await messaging.getToken();
    print(token);
  }

  void handleRemoteMessage(RemoteMessage message) {
    if (message.notification == null) return;

    final notification = PushMessage(
      messageId: message.messageId?.replaceAll(':', '').replaceAll('%', '') ?? '',
      title: message.notification!.title ?? '',
      body: message.notification!.body ?? '',
      sendDate: message.sentTime ?? DateTime.now(),
      data: message.data,
      imageUrl: Platform.isAndroid
        ? message.notification!.android?.imageUrl
        : message.notification!.apple?.imageUrl
    );

    print(notification.messageId.toString());
    add(NotificationsRecivied(notification));
  }

  void _onForegroundMessage() {
    FirebaseMessaging.onMessage.listen(handleRemoteMessage);
  }

  void requestPermision() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, //Recibir notificaciones
      announcement: false, //Reproducción de notificaciones
      badge: true,
      carPlay: false, //Recibir notificaciones si se encuentra en el auto (con app iOS CarPlay)
      criticalAlert: true, //Urgencia de las notificaciones
      provisional: false,
      sound: true, //Reproducir un sonido con la notificación
    );

    add(NotificationStatusChanged(settings.authorizationStatus));
    //_getFCMToken();
  }

  //Obtener notificacion push
  PushMessage? getMessageById(String pushMessageId){
    final exist =  state.notifications.any((element) => element.messageId == pushMessageId);
    if(!exist) return null;

    return state.notifications.firstWhere((element) => element.messageId == pushMessageId);
  }
}
