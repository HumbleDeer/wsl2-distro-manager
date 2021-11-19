import 'analytics.dart';
import 'api.dart';
import 'dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DistroList extends StatefulWidget {
  const DistroList({Key? key, required this.api, required this.statusMsg})
      : super(key: key);

  final WSLApi api;
  final Function(String, {bool loading}) statusMsg;

  @override
  _DistroListState createState() => _DistroListState();
}

class _DistroListState extends State<DistroList> {
  Map<String, bool> hover = {};
  void update(var item, bool enter) {
    setState(() {
      hover[item] = enter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return distroList(widget.api, widget.statusMsg, update, hover);
  }
}

FutureBuilder<Instances> distroList(
    WSLApi api,
    Function(String, {bool loading}) statusMsg,
    Function(dynamic, bool) update,
    Map<String, bool> hover) {
  isRunning(String distroName, List<String> runningList) {
    if (runningList.contains(distroName)) {
      return true;
    }
    return false;
  }

  return FutureBuilder<Instances>(
    future: api.list(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        List<Widget> newList = [];
        List<String> list = snapshot.data?.all ?? [];
        List<String> running = snapshot.data?.running ?? [];
        // Check if there are distros
        if (list.isEmpty) {
          return const Expanded(
            child: Center(
              child: Text('No distros found.'),
            ),
          );
        }
        // Check if WSL is installed
        if (list[0] == 'wslNotInstalled') {
          return const InstallDialog();
        }
        for (String item in list) {
          newList.add(Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: MouseRegion(
              onEnter: (event) {
                update(item, true);
              },
              onExit: (event) {
                update(item, false);
              },
              child: ListTile(
                tileColor: (hover[item] != null && hover[item]!)
                    ? const Color.fromRGBO(0, 0, 0, 0.2)
                    : Colors.transparent,
                /* tileColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10.0))), */
                title: isRunning(item, running)
                    ? (Text(item + ' (running)'))
                    : Text(item), // running here
                leading: Row(children: [
                  Tooltip(
                    message: 'Start',
                    child: IconButton(
                      icon: const Icon(FluentIcons.play),
                      onPressed: () {
                        plausible.event(name: "wsl_started");
                        api.start(item);
                        Future.delayed(const Duration(milliseconds: 500),
                            statusMsg('$item started.'));
                      },
                    ),
                  ),
                  isRunning(item, running)
                      ? Tooltip(
                          message: 'Stop',
                          child: IconButton(
                            icon: const Icon(FluentIcons.stop),
                            onPressed: () {
                              plausible.event(name: "wsl_stopped");
                              api.stop(item);
                              statusMsg('$item stopped.');
                            },
                          ),
                        )
                      : const Text(''),
                ]),
                trailing: Row(
                  children: [
                    Tooltip(
                      message: 'Open with File Explorer',
                      child: IconButton(
                        icon: const Icon(FluentIcons.open_folder_horizontal),
                        onPressed: () async {
                          plausible.event(name: "wsl_explorer");
                          api.startExplorer(item);
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Open with Visual Studio Code',
                      child: IconButton(
                        icon: const Icon(FluentIcons.visual_studio_for_windows),
                        onPressed: () async {
                          plausible.event(name: "wsl_vscode");
                          api.startVSCode(item);
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Copy',
                      child: IconButton(
                        icon: const Icon(FluentIcons.copy),
                        onPressed: () async {
                          copyDialog(context, item, api, statusMsg);
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Rename',
                      child: IconButton(
                        icon: const Icon(FluentIcons.rename),
                        onPressed: () {
                          renameDialog(context, item, api, statusMsg);
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Delete',
                      child: IconButton(
                          icon: const Icon(FluentIcons.delete),
                          onPressed: () {
                            deleteDialog(context, item, api, statusMsg);
                          }),
                    ),
                  ],
                ),
              ),
            ),
          ));
        }
        return Expanded(
          child: ListView.custom(
            childrenDelegate: SliverChildListDelegate(newList),
          ),
        );
      } else if (snapshot.hasError) {
        return Text('${snapshot.error}');
      }

      // By default, show a loading spinner.
      return const Center(child: ProgressRing());
    },
  );
}

deleteDialog(context, item, api, Function(String, {bool loading}) statusMsg) {
  dialog(
      context: context,
      item: item,
      api: api,
      statusMsg: statusMsg,
      title: 'Delete $item permanently?',
      body: 'If you delete this Distro you won\'t be able to recover it.'
          ' Do you want to delete it?',
      submitText: 'Delete',
      submitInput: false,
      submitStyle: ButtonStyle(
        backgroundColor: ButtonState.all(Colors.red),
        foregroundColor: ButtonState.all(Colors.white),
      ),
      onSubmit: (inputText) async {
        api.remove(item);
        statusMsg('DONE: Deleted $item.');
      });
}

renameDialog(context, item, api, Function(String, {bool loading}) statusMsg) {
  dialog(
      context: context,
      item: item,
      api: api,
      statusMsg: statusMsg,
      title: 'Rename $item',
      body: 'Warning: Renaming will recreate the whole WSL2 instance.',
      submitText: 'Rename',
      submitStyle: const ButtonStyle(),
      onSubmit: (inputText) async {
        statusMsg('Renaming $item to $inputText. This might take a while...',
            loading: true);
        await api.copy(item, inputText);
        await api.remove(item);
        statusMsg('DONE: Renamed $item to $inputText.');
      });
}

copyDialog(context, item, api, Function(String, {bool loading}) statusMsg) {
  dialog(
      context: context,
      item: item,
      api: api,
      statusMsg: statusMsg,
      title: 'Copy \'$item\'',
      body: 'Copy the WSL instance \'$item.\'',
      submitText: 'Copy',
      submitStyle: const ButtonStyle(),
      onSubmit: (inputText) async {
        statusMsg('Copying $item. This might take a while...', loading: true);
        await api.copy(item, inputText);
        statusMsg('DONE: Copied $item to $inputText.');
      });
}

class InstallDialog extends StatelessWidget {
  const InstallDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('WSL is not installed.'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                  'You can install it with following command in the Terminal:'),
            ),
            Container(
              color: const Color.fromRGBO(0, 0, 0, 0.2),
              child: Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 4.0),
                  child: TextButton(
                      onPressed: () async {
                        plausible.event(name: "wsl_install");
                        WSLApi().installWSL();
                      },
                      child: const Text("wsl --install"))),
            ),
          ],
        ),
      ),
    );
  }
}
