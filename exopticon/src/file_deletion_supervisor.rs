use actix::*;

use crate::file_deletion_actor::FileDeletionActor;
use crate::models::{DbExecutor, FileExecutor};

/// Request supervisor to start file deletion actor
pub struct StartDeletionWorker {
    /// address of database actor
    pub db_addr: Addr<DbExecutor>,
    /// id of camera group actor is to work for
    pub camera_group_id: i32,
}

impl Message for StartDeletionWorker {
    type Result = ();
}

/// File Deletion Supervisor actor state
pub struct FileDeletionSupervisor {
    /// address of sync arbiter for fs actor
    pub fs_actor: Addr<FileExecutor>,

    /// tuple of camera group id and address of file deletion actor
    workers: Vec<(i32, Addr<FileDeletionActor>)>,
}

impl Actor for FileDeletionSupervisor {
    type Context = Context<Self>;
}

impl Handler<StartDeletionWorker> for FileDeletionSupervisor {
    type Result = ();

    fn handle(&mut self, msg: StartDeletionWorker, _ctx: &mut Context<Self>) -> Self::Result {
        debug!(
            "FileDeletionSupervisor: Starting worker for camera group id: {}",
            msg.camera_group_id
        );
        let id = msg.camera_group_id;
        let address =
            FileDeletionActor::new(msg.camera_group_id, self.fs_actor.clone(), msg.db_addr).start();
        self.workers.push((id, address));
    }
}

impl FileDeletionSupervisor {
    /// Create new file deletion supervisor

    pub fn new() -> Self {
        #![allow(clippy::missing_const_for_fn)] // Vec::new not allowed in const_fn
        let fs_actor = SyncArbiter::start(2, || FileExecutor {});

        Self {
            fs_actor,
            workers: Vec::new(),
        }
    }
}
