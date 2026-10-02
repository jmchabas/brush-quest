// Unit tests for the cloud-backup retention job (src/cleanup.js).
// Run with `npm test` (node:test, no Firebase needed).

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  RETENTION_DAYS,
  PAGE_SIZE,
  FAILED_PRECONDITION,
  retentionCutoff,
  deleteStaleBackups,
} = require('../src/cleanup');

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2027, 9, 2, 10, 30); // 2027-10-02T10:30Z

// In-memory stand-in for the parts of the Admin SDK the job uses:
// collection('users').where('last_sync', '<', date).limit(n).get(), and
// doc.ref.delete({ lastUpdateTime }) which, like Firestore, rejects with
// FAILED_PRECONDITION when the document changed since that version.
function fakeDb(docs) {
  const store = new Map();
  let version = 0;
  for (const [id, d] of Object.entries(docs)) {
    version += 1;
    store.set(id, { ...d, updateTime: version });
  }
  const db = {
    store,
    queries: 0,
    afterQuery: null, // test hook: runs after a query returns its page
    touch(id, lastSync) {
      version += 1;
      store.set(id, { last_sync: lastSync, updateTime: version });
    },
    collection(name) {
      assert.equal(name, 'users');
      return {
        where(field, op, value) {
          assert.equal(field, 'last_sync');
          assert.equal(op, '<');
          assert.ok(value instanceof Date, 'cutoff must be a Date');
          return {
            limit(n) {
              return {
                async get() {
                  db.queries += 1;
                  const page = [...store.entries()]
                    .filter(([, d]) => d.last_sync instanceof Date && d.last_sync < value)
                    .slice(0, n)
                    .map(([id, d]) => ({
                      id,
                      updateTime: d.updateTime,
                      ref: {
                        id,
                        async delete(precondition) {
                          assert.ok(precondition, 'delete must carry a precondition');
                          const current = store.get(id);
                          if (!current) return;
                          if (current.updateTime !== precondition.lastUpdateTime) {
                            const err = new Error('FAILED_PRECONDITION');
                            err.code = FAILED_PRECONDITION;
                            throw err;
                          }
                          store.delete(id);
                        },
                      },
                    }));
                  if (db.afterQuery) db.afterQuery();
                  return { empty: page.length === 0, size: page.length, docs: page };
                },
              };
            },
          };
        },
      };
    },
  };
  return db;
}

const daysAgo = (days) => new Date(NOW - days * DAY_MS);

test('cutoff is exactly 365 days before now', () => {
  assert.equal(RETENTION_DAYS, 365);
  assert.equal(retentionCutoff(NOW).getTime(), NOW - 365 * DAY_MS);
});

test('deletes backups last saved more than 12 months ago, keeps the rest', async () => {
  const cutoff = retentionCutoff(NOW);
  const db = fakeDb({
    stale400: { last_sync: daysAgo(400) },
    stale366: { last_sync: daysAgo(366) },
    staleByOneMs: { last_sync: new Date(cutoff.getTime() - 1) },
    atCutoff: { last_sync: new Date(cutoff.getTime()) },
    fresh364: { last_sync: daysAgo(364) },
    freshToday: { last_sync: daysAgo(0) },
    noLastSync: {},
  });

  const deleted = await deleteStaleBackups(db, cutoff);

  assert.equal(deleted, 3);
  assert.deepEqual(
    [...db.store.keys()].sort(),
    ['atCutoff', 'fresh364', 'freshToday', 'noLastSync'],
  );
});

test('pages through more stale backups than one query returns', async () => {
  const docs = {};
  const total = PAGE_SIZE * 2 + 50;
  for (let i = 0; i < total; i += 1) docs[`old${i}`] = { last_sync: daysAgo(500) };
  docs.keep = { last_sync: daysAgo(10) };
  const db = fakeDb(docs);

  const deleted = await deleteStaleBackups(db, retentionCutoff(NOW));

  assert.equal(deleted, total);
  assert.deepEqual([...db.store.keys()], ['keep']);
  assert.equal(db.queries, 4); // 300 + 300 + 50, then an empty page
});

test('no stale backups: nothing is deleted after one query', async () => {
  const db = fakeDb({
    a: { last_sync: daysAgo(1) },
    b: { last_sync: daysAgo(200) },
    c: {},
  });

  const deleted = await deleteStaleBackups(db, retentionCutoff(NOW));

  assert.equal(deleted, 0);
  assert.equal(db.queries, 1);
  assert.equal(db.store.size, 3);
});

test('a backup saved again after the query ran is kept', async () => {
  const db = fakeDb({
    staleA: { last_sync: daysAgo(400) },
    racer: { last_sync: daysAgo(400) },
    staleB: { last_sync: daysAgo(400) },
  });
  // The family syncs between the query and the delete.
  db.afterQuery = () => {
    db.afterQuery = null;
    db.touch('racer', daysAgo(0));
  };

  const deleted = await deleteStaleBackups(db, retentionCutoff(NOW));

  assert.equal(deleted, 2);
  assert.deepEqual([...db.store.keys()], ['racer']);
});

test('other delete errors are not swallowed', async () => {
  const db = fakeDb({ stale: { last_sync: daysAgo(400) } });
  const realCollection = db.collection.bind(db);
  db.collection = (name) => {
    const q = realCollection(name);
    return {
      where: (...w) => ({
        limit: (n) => ({
          async get() {
            const snap = await q.where(...w).limit(n).get();
            snap.docs.forEach((doc) => {
              doc.ref.delete = async () => {
                const err = new Error('PERMISSION_DENIED');
                err.code = 7;
                throw err;
              };
            });
            return snap;
          },
        }),
      }),
    };
  };

  await assert.rejects(deleteStaleBackups(db, retentionCutoff(NOW)), /PERMISSION_DENIED/);
});

test('stops instead of looping forever if deletes do not take effect', async () => {
  const db = fakeDb({ stuck: { last_sync: daysAgo(400) } });
  const realCollection = db.collection.bind(db);
  db.collection = (name) => {
    const q = realCollection(name);
    return {
      where: (...w) => ({
        limit: (n) => ({
          async get() {
            const snap = await q.where(...w).limit(n).get();
            snap.docs.forEach((doc) => {
              doc.ref.delete = async () => {}; // silently drops the delete
            });
            return snap;
          },
        }),
      }),
    };
  };

  await assert.rejects(deleteStaleBackups(db, retentionCutoff(NOW)), /did not shrink/);
});
