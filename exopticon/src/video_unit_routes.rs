// We have to pass by value to satisfy the actix route interface.
#![allow(clippy::needless_pass_by_value)]

use actix_web::{web::Data, web::Path, web::Query, Error, HttpResponse};
use chrono::{DateTime, Utc};

use crate::app::RouteState;
use crate::models::{FetchBetweenVideoUnit, FetchVideoUnit};

/// Implements route that fetches a single `VideoUnit` specified by id.
///
/// # Arguments
///
/// * `path` - `Path` containing `VideoUnit` id
/// * `state` - `RouteState` struct
///
pub async fn fetch_video_unit(
    path: Path<i32>,
    state: Data<RouteState>,
) -> Result<HttpResponse, Error> {
    let db_response = state
        .db
        .send(FetchVideoUnit {
            id: path.into_inner(),
        })
        .await?;

    match db_response {
        Ok(video_unit) => Ok(HttpResponse::Ok().json(video_unit)),
        Err(err) => Ok(HttpResponse::InternalServerError().json(err.to_string())),
    }
}

/// Struct used to match time parameters on api route
#[derive(Deserialize)]
pub struct DateRange {
    /// end time - inclusive
    pub end_time: DateTime<Utc>,
    /// begin_time - exclusive
    pub begin_time: DateTime<Utc>,
}

/// Implements route that fetches `VideoUnit`s from the database
/// between the specified times, inclusively.
///
/// # Arguments
///
/// * `camera_id` - id of camera to fetch video for
/// * `begin` - begin time in UTC
/// * `end` - end time in UTC
/// * `state` - `RouteState` struct
///
pub async fn fetch_video_units_between(
    camera_id: Path<i32>,
    range: Query<DateRange>,
    state: Data<RouteState>,
) -> Result<HttpResponse, Error> {
    let db_response = state
        .db
        .send(FetchBetweenVideoUnit {
            camera_id: camera_id.into_inner(),
            begin_time: range.begin_time,
            end_time: range.end_time,
        })
        .await?;

    match db_response {
        Ok(video_units) => Ok(HttpResponse::Ok().json(video_units)),
        Err(err) => Ok(HttpResponse::InternalServerError().json(err.to_string())),
    }
}
