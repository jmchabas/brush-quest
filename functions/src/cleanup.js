/**
 * Cloud-backup retention (privacy policy: "deleted automatically 12 months
 * after the last cloud save").
 *
 * Each signed-in family has one Firestore document, `users/{uid}`. The app
 * writes `last_sync = serverTimestamp()` on every upload
 * (lib/services/sync_service.dart), so a document whose `last_sync` is more
 * than 365 days old belongs to a backup nobody has used for a year.
 *
 * Documents without `last_sync` never match the range query, so they are
 * never deleted here. Firebase Auth sign-in records are not touched: the
 * policy keeps those until the parent uses Delete Account.
 *
 * Kept free of firebase-functions so it can be unit tested with a fake
 * Firestore handle (test/cleanup.test.js); index.js schedules it.
 */

const RETENTION_DAYS = 365;
const PAGE_SIZE = 300;
const DAY_MS = 24 * 60 * 60 * 1000;

// gRPC status Firestore returns when a delete's lastUpdateTime precondition
// no longer matches the stored document.
const FAILED_PRECONDITION = 9;

function retentionCutoff(nowMs) {
  return new Date(nowMs - RETENTION_DAYS * DAY_MS);
}

/**
 * Deletes every `users/{uid}` document whose `last_sync` is strictly older
 * than `cutoff`, one page at a time, until the query comes back empty.
 * Returns the number of documents deleted.
 *
 * Each delete carries the `updateTime` the query saw as a precondition: if
 * the family saved a new backup after the query ran, Firestore rejects that
 * delete with FAILED_PRECONDITION and the fresh backup is kept.
 *
 * Deleted documents drop out of the next query, so the next query returns
 * the next page. A page that repeats a document already handled means the
 * deletes are not taking effect: throw instead of looping forever.
 */
async function deleteStaleBackups(db, cutoff) {
  const handled = new Set();
  let deleted = 0;
  for (;;) {
    const snap = await db
      .collection('users')
      .where('last_sync', '<', cutoff)
      .limit(PAGE_SIZE)
      .get();
    if (snap.empty) return deleted;

    for (const doc of snap.docs) {
      if (handled.has(doc.id)) {
        throw new Error(
          'cleanupStaleBackups: stale-backup query did not shrink after delete',
        );
      }
      handled.add(doc.id);
      try {
        await doc.ref.delete({ lastUpdateTime: doc.updateTime });
        deleted += 1;
      } catch (err) {
        if (err && err.code === FAILED_PRECONDITION) continue; // saved again
        throw err;
      }
    }
  }
}

module.exports = {
  RETENTION_DAYS,
  PAGE_SIZE,
  FAILED_PRECONDITION,
  retentionCutoff,
  deleteStaleBackups,
};
