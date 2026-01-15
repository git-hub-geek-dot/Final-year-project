import 'register_base_screen.dart';

class RegisterVolunteerScreen extends RegisterBaseScreen {
  const RegisterVolunteerScreen({super.key});

  @override
  String get role => "volunteer";

  @override
  bool get showVolunteerFields => true;
}