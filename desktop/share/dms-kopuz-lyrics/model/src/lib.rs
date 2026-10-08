pub mod lyrics;
pub async fn sleep(duration: std::time::Duration) {
    tokio::time::sleep(duration).await;
}
