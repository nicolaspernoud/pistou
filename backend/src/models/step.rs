use actix_files::NamedFile;

use actix_web::Result;
use futures_util::StreamExt;
use image::GenericImageView;
use std::fs::{self};

use image::imageops::FilterType::Lanczos3;
use serde::{Deserialize, Serialize};

use crate::{
    crud_delete_all, crud_read, crud_read_all, crud_use, errors::ServerError, schema::steps,
};

macro_rules! trim {
    () => {
        fn trim(&mut self) -> &Self {
            self.location_hint = self.location_hint.trim().to_string();
            self.question = self.question.trim().to_string();
            self.answer = self.answer.trim().to_string();
            self.media = self.media.trim().to_string();
            self
        }
    };
}

#[derive(
    Debug,
    Clone,
    Serialize,
    Deserialize,
    Queryable,
    Insertable,
    AsChangeset,
    Identifiable,
    Associations,
)]
#[table_name = "steps"]
pub struct Step {
    pub id: i32,
    pub rank: i32,
    pub latitude: f64,
    pub longitude: f64,
    pub location_hint: String,
    pub question: String,
    pub answer: String,
    pub media: String,
    #[serde(default)]
    pub is_end: bool,
}

fn rerank(
    conn: &r2d2::PooledConnection<ConnectionManager<SqliteConnection>>,
) -> Result<(), diesel::result::Error> {
    use crate::schema::steps::dsl::*;
    let mut i = 0;
    // get the steps
    let steps_vec = steps.order(rank.asc()).load::<Step>(conn)?;

    for v in steps_vec {
        i = i + 1;
        // alter the steps
        diesel::update(steps)
            .filter(id.eq(v.id))
            .set(rank.eq(i))
            .execute(conn)?;
    }
    Ok(())
}

impl Step {
    trim!();
}

#[derive(Debug, Clone, Serialize, Deserialize, Insertable)]
#[table_name = "steps"]
pub struct NewStep {
    pub rank: i32,
    pub latitude: f64,
    pub longitude: f64,
    pub location_hint: String,
    pub question: String,
    pub answer: String,
    pub media: String,
    #[serde(default)]
    pub is_end: bool,
}

impl NewStep {
    trim!();
}

crud_use!();

#[post("")]
pub async fn create(
    pool: web::Data<DbPool>,
    mut o: web::Json<NewStep>,
) -> Result<HttpResponse, ServerError> {
    let conn = pool.get()?;
    let s = web::block(move || {
        use crate::schema::steps::dsl::*;
        o.trim();
        diesel::insert_into(steps).values(&*o).execute(&conn)?;
        // Renumber the steps
        rerank(&conn)?;
        steps.order(id.desc()).first::<Step>(&conn)
    })
    .await??;
    Ok(HttpResponse::Created().json(s))
}

#[delete("/{oid}")]
pub async fn delete(
    pool: web::Data<DbPool>,
    oid: web::Path<i32>,
) -> Result<HttpResponse, ServerError> {
    let conn = pool.get()?;
    let oid = *oid;
    web::block(move || {
        use crate::schema::steps::dsl::*;
        let deleted = diesel::delete(steps).filter(id.eq(oid)).execute(&conn)?;
        rerank(&conn)?;
        match deleted {
            0 => Err(diesel::result::Error::NotFound),
            _ => Ok(deleted),
        }
    })
    .await??;
    let _ = web::block(move || fs::remove_file(photo_filename(oid))).await;
    Ok(HttpResponse::Ok().body(format!("Deleted object with id: {}", oid)))
}

#[put("/{oid}")]
pub async fn update(
    pool: web::Data<DbPool>,
    mut o: web::Json<Step>,
    oid: web::Path<i32>,
) -> Result<HttpResponse, ServerError> {
    let conn = pool.get()?;
    o.trim();
    let put_o = web::block(move || {
        use crate::schema::steps::dsl::*;
        diesel::update(steps)
            .filter(id.eq(*oid))
            .set(&*o)
            .execute(&conn)?;
        rerank(&conn)?;
        steps.filter(id.eq(*oid)).first::<Step>(&conn)
    })
    .await??;
    Ok(HttpResponse::Ok().json(put_o))
}

crud_read_all!(Step, steps);
crud_read!(Step, steps);
crud_delete_all!(Step, steps);

///////////////////////
// IMAGES MANAGEMENT //
///////////////////////

const IMAGES_PATH: &str = "data/items/images";

#[post("/images/{oid}")]
async fn upload_image(
    oid: web::Path<i32>,
    mut body: web::Payload,
) -> Result<HttpResponse, ServerError> {
    fs::create_dir_all(IMAGES_PATH)?;
    let filename = photo_filename(*oid);
    let mut bytes = web::BytesMut::new();
    while let Some(item) = body.next().await {
        bytes.extend_from_slice(&item?);
    }
    let r = web::block(move || image::load_from_memory(&bytes)).await?;

    if let Ok(r) = r {
        r.resize(
            std::cmp::min(1280, r.dimensions().0),
            std::cmp::min(1280, r.dimensions().1),
            Lanczos3,
        )
        .save_with_format(
            &filename,
            image::ImageFormat::from_extension("jpg").unwrap(),
        )?;
        Ok(HttpResponse::Ok().body(filename))
    } else {
        let res = HttpResponse::InternalServerError().body("Error loading image");
        Ok(res)
    }
}

#[get("/images/{oid}")]
async fn retrieve_image(oid: web::Path<i32>) -> Result<NamedFile> {
    Ok(NamedFile::open(photo_filename(*oid))?)
}

#[delete("/images/{oid}")]
async fn delete_image(oid: web::Path<i32>) -> Result<HttpResponse, ServerError> {
    let d = web::block(move || fs::remove_file(photo_filename(*oid))).await?;
    if let Ok(_) = d {
        Ok(HttpResponse::Ok().body("File deleted"))
    } else {
        let res = HttpResponse::NotFound().body("File not found");
        Ok(res)
    }
}

fn photo_filename(id: i32) -> String {
    format!("{path}/{id}.jpg", path = IMAGES_PATH, id = id)
}
