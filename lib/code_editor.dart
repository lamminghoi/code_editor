library code_editor;

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'ToolButton.dart';

part 'EditorModel.dart';
part 'FileEditor.dart';
part 'EditorModelStyleOptions.dart';
part 'Theme.dart';

/// Creates a code editor that helps users to write and read code.
///
/// In order to use it, you must define :
/// * [model] an EditorModel, to control the editor, its content and its files
/// * [onSubmit] a Function(String language, String value) executed when the user submits changes in a file.
class CodeEditor extends StatefulWidget {
  /// The EditorModel in order to control the editor.
  ///
  /// This argument is @required.
  late final EditorModel? model;

  /// onSubmit function to execute when the user saves changes in a file.
  /// This is a function that takes [language] and [value] as arguments.
  ///
  /// * [language] is the language of the file edited by the user.
  /// * [value] is the content of the file.
  final Function(String? language, String? value)? onSubmit;

  final Function(String? language, String? value)? onChanged;

  /// You can disable the edit button (it won't show up at all) just like this :
  ///
  /// ```
  /// CodeEditor(
  ///   model: model, // my EditorModel()
  ///   edit: false, // disable the edit button
  /// )
  /// ```
  ///
  /// By default, the value is true.
  final bool edit;

  /// You can disable the navigation bar like this :
  ///
  /// ```
  /// CodeEditor(
  ///   model: model, // my EditorModel()
  ///   disableNavigationbar: true, // hide the navigation bar
  /// )
  /// ```
  ///
  /// By default, the value is `false`.
  ///
  /// WARNING : if you set the value to true, only the first
  /// file will be displayed in the editor because
  /// it's not possible to switch betweens other files without the navigation bar.
  final bool disableNavigationbar;

  /// An optional TextEditingController that can be passed in.
  late final TextEditingController? textEditingController;

  CodeEditor({
    Key? key,
    this.model,
    this.onSubmit,
    this.onChanged,
    this.edit = true,
    this.disableNavigationbar = false,
    this.textEditingController,
  }) : super(key: key);

  @override
  _CodeEditorState createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  /// We need it to control the content of the text field.
  late TextEditingController editingController;

  /// The new content of a file when the user is editing one.
  String? newValue;

  /// The text field wants a focus node.
  FocusNode focusNode = FocusNode();

  /// Initialize the formKey for the text field
  static final GlobalKey<FormState> editableTextKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    if (widget.textEditingController != null) {
      // Use the user-provide controller
      editingController = widget.textEditingController!;
    } else {
      /// Initialize the controller for the text field.
      editingController = TextEditingController(text: "");
    }
    newValue = ""; // if there are no changes
  }

  @override
  void dispose() {
    editingController.dispose();
    super.dispose();
  }

  /// Set the cursor at the end of the editableText.
  void placeCursorAtTheEnd() {
    editingController.selection = TextSelection.fromPosition(
      TextPosition(offset: 0),
    );
  }

  /// Place the cursor where wanted.
  ///
  /// [pos] places the cursor in the text field
  void placeCursor(int pos) {
    try {
      editingController.selection = TextSelection.fromPosition(
        TextPosition(offset: pos),
      );
    } catch (e) {
      throw Exception("code_editor : placeCursor(int pos), pos is not valid.");
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Gets the model from the parent widget.
    EditorModel model = widget.model ??= EditorModel(files: []);

    /// Gets the style options from the parent widget.
    EditorModelStyleOptions? opt = model.styleOptions;

    String? language = model.currentLanguage;

    /// Which file in the list of file ?
    int? position = model.position;

    /// The content of the file where position corresponds to the list of file.
    String? code = model.getCodeWithIndex(position ?? 0);

    bool disableNavigationbar = widget.disableNavigationbar;

    // When we change the file in the navbar, the code in the text field
    // isn't updated, so we update it here.
    //
    // With newValue = code if the user does not change the value
    // in the text field
    editingController = TextEditingController(text: code);
    newValue = code;

    /// The filename in green.
    Text showFilename(String name, bool isSelected) {
      return Text(
        name,
        style: TextStyle(
          fontFamily: "monospace",
          letterSpacing: 1.0,
          fontWeight: FontWeight.normal,
          fontSize: opt?.fontSizeOfFilename,
          color: isSelected ? opt?.editorFilenameColor : opt?.editorFilenameColor.withOpacity(0.5),
        ),
      );
    }

    /// Build the navigation bar.
    Container buildNavbar() {
      return Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: opt?.editorColor,
          border: Border(bottom: BorderSide(color: opt?.editorBorderColor ?? Colors.blue)),
        ),
        child: ListView.builder(
          padding: EdgeInsets.only(left: 15),
          itemCount: model.numberOfFiles,
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, int index) {
            final FileEditor file = model.getFileWithIndex(index);

            return Container(
              margin: EdgeInsets.only(right: 15),
              child: Center(
                child: GestureDetector(
                  // Checks if the position of the navbar is the current file.
                  child: showFilename(file.name, model.position == index),
                  onTap: () {
                    setState(() {
                      model.changeIndexTo(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    /// Creates the text field.
    SingleChildScrollView buildEditableText() {
      return SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            right: 10,
            left: 10,
            top: 10,
            bottom: 50,
          ),
          child: TextField(
            decoration: InputDecoration(border: InputBorder.none),
            autofocus: true,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            style: opt?.textStyleOfTextField,
            focusNode: focusNode,
            controller: editingController,
            onChanged: (String v) {
              newValue = v;
              widget.onChanged?.call(language, newValue);
            },
            key: editableTextKey,
            toolbarOptions: model.styleOptions?.toolbarOptions,
          ),
        ),
      );
    }

    /// Creates the edit button and the save button ("OK") with a
    /// particual function [press] to execute.
    ///
    /// This button won't appear if `edit = false`.
    Widget editButton(String name, Function() press) {
      if (widget.edit == true) {
        return Positioned(
          bottom: opt?.editButtonPosBottom,
          right: opt?.editButtonPosRight,
          top: (model.isEditing &&
                  opt != null &&
                  opt.editButtonPosTop != null &&
                  opt.editButtonPosTop! < 50)
              ? 50
              : opt?.editButtonPosTop,
          left: opt?.editButtonPosLeft,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              primary: opt?.editButtonBackgroundColor,
            ),
            onPressed: press,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16.0,
                fontFamily: "monospace",
                fontWeight: FontWeight.normal,
                color: opt?.editButtonTextColor,
              ),
            ),
          ),
        );
      } else {
        return SizedBox.shrink();
      }
    }
    // We place the cursor in the end of the text field.

    if (model.isEditing && (model.styleOptions?.placeCursorAtTheEndOnEdit ?? true)) {
      placeCursorAtTheEnd();
    }

    /// We toggle the editor and the text field.
    Widget buildContentEditor() {
      return model.isEditing
          ? Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    // Container of the EditableText
                    Container(
                      width: double.infinity,
                      height: opt?.heightOfContainer,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: opt?.editorBorderColor.withOpacity(0.4) ??
                                Colors.blue.withOpacity(0.4),
                          ),
                        ),
                      ),
                      child: buildEditableText(),
                    ),
                  ],
                ),
                // The OK button
                editButton("OK", () {
                  setState(() {
                    model.updateCodeOfIndex(position ?? 0, newValue);
                    model.toggleEditing();
                    widget.onSubmit?.call(language, newValue);
                  });
                }),
              ],
            )
          : Stack(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: opt?.heightOfContainer,
                  color: opt?.editorColor,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: opt?.padding ?? const EdgeInsets.all(3.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          HighlightView(
                            code ?? "code is null",
                            language: language,
                            theme: opt?.theme ?? githubTheme,
                            tabSize: opt?.tabSize ?? 4,
                            textStyle: TextStyle(
                              fontFamily: opt?.fontFamily,
                              letterSpacing: opt?.letterSpacing,
                              fontSize: opt?.fontSize,
                              height: opt?.lineHeight, // line-height
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                editButton(opt?.editButtonName ?? "Edit", () {
                  setState(() {
                    model.toggleEditing();
                  });
                }),
              ],
            );
    }

    return Column(
      children: <Widget>[
        disableNavigationbar ? SizedBox.shrink() : buildNavbar(),
        buildContentEditor(),
      ],
    );
  }
}
