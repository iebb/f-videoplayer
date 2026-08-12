import 'package:flutter/widgets.dart';

import 'desktop_video_window_arguments.dart';

Widget buildDesktopWindowHost({
  required FVideoDesktopWindowArguments initialArguments,
  required Widget Function(
    BuildContext context,
    FVideoDesktopWindowArguments arguments,
  )
  builder,
  WidgetBuilder? loadingBuilder,
}) => Builder(builder: (context) => builder(context, initialArguments));
