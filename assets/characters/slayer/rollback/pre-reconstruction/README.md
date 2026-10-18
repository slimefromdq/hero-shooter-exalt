# Before the facial reconstruction

Unmodified prior `slayer.blend`, `slayer.glb`, `face-config.json`, `model-report.json`, both generator modules and three actual comparison renders. These preserve the fuller-lips / softened-lids revision as a rollback.

To restore, first back up the current files. Copy this folder's `.blend`, `.glb` and configuration/report to the parent Slayer asset folder, and the two Python modules to `tools/blender/`. Do not run the generator directly from this archive: its repository-root discovery assumes the normal tools location. Restore matching validation scripts from version control or update them for the six-key rollback asset before rerunning checks.

Godot intentionally keeps the native source file and imports the explicit GLB. The protected-component comparison loads this native source as its baseline.
