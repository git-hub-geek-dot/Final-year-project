import 'register_base_screen.dart';

class RegisterOrganiserScreen extends RegisterBaseScreen {
  const RegisterOrganiserScreen({super.key});

  @override
  String get role => "organiser";

  @override
  bool get showOrganiserFields => true;
}
