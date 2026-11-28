import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';

const String foldersIntro =
    'Synthesis files each note in one of these folders. The description tells it what belongs there.';

/// Under the description field of the folder editor: the description is what Synthesis reads.
const String folderDescriptionHelp =
    'Synthesis reads this description to decide which notes belong in this folder. Add your own words — topics, people, projects — to make it more accurate.';

const String uncategorizedNote = 'Catches whatever fits no other folder. It cannot be changed.';

String folderLimitHint() => 'You can have up to $maxFolderCount folders.';

String deleteFolderMessage(String name) => 'Notes in "$name" will move to Uncategorized.';

/// A plain-words reason a folder change did not happen. Empty for [FolderChange.done].
String folderChangeMessage(FolderChange change) => switch (change) {
      FolderChange.done => '',
      FolderChange.nameEmpty => 'Give the folder a name.',
      FolderChange.nameTooLong => 'A folder name can be up to $maxFolderNameLength characters.',
      FolderChange.nameInvalid => 'A folder name must be a single line of text.',
      FolderChange.nameTaken => 'There is already a folder with this name.',
      FolderChange.tooManyFolders => folderLimitHint(),
      FolderChange.descriptionTooLong => 'A description can be up to $maxFolderDescriptionLength characters.',
      FolderChange.protectedFolder => 'Uncategorized cannot be changed.',
      FolderChange.notFound => 'This folder no longer exists.',
      FolderChange.styleUnknown => 'Choose one of the listed styles.',
    };

/// The folder list's line for a folder's default style; null for organised, which is not shown.
String? folderStyleLine(String styleId) =>
    styleId == defaultNoteStyleId ? null : 'Style: ${noteStyleLabel(styleId)}';
