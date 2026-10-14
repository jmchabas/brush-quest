# Marketing videos

Video files are not kept in git. Promos, clips and App Store previews are on Google Drive:
https://drive.google.com/drive/folders/1LGYfGTlqiEny2Mhqs8Of8DRt9Ysh5Zz5
(rclone: `gdrive:Projects/backups/media/brush-quest/`, same paths as in the repo, e.g.
`marketing/video/promo_v5_26s.mp4`, `marketing/screenshots/ios/preview_6.7.mp4`).

Upload new renders with:
`rclone copy marketing/video "gdrive:Projects/backups/media/brush-quest/marketing/video" --include "*.mp4"`

Only exception in git: `docs/gameplay.mp4`, served by the brushquest.app landing page.
