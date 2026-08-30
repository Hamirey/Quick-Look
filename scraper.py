import os
import re
import sys
import logging
from datetime import datetime, timezone
from urllib.parse import quote_plus
from dotenv import load_dotenv
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError
from supabase import create_client, Client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("x_scraper")

# Load environment variables
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    logger.error("Missing SUPABASE_URL or SUPABASE_KEY in environment variables.")
    sys.exit(1)

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# List of public X / Nitter mirror instances
MIRROR_INSTANCES = [
    "https://xcancel.com",
    "https://nitter.poast.org",
    "https://nitter.privacydev.net"
]

# Category search queries targeting viral Nigerian content with min_faves:500
CATEGORIES = {
    "Afrobeats": '(Afrobeats OR Wizkid OR Burna OR Davido OR Asake OR Rema OR "Tems" OR Olamide) min_faves:500',
    "Nollywood": '(Nollywood OR "Nigerian movie" OR "Funke Akindele" OR "Genevieve Nnaji" OR "Kunle Afolayan") min_faves:500',
    "Tech": '("Nigeria tech" OR "Lagos tech" OR Flutterwave OR Paystack OR "tech in Nigeria" OR "Nigerian startup") min_faves:500',
    "Politics": '(Tinubu OR "Peter Obi" OR INEC OR "Nigerian politics" OR "Nigeria election" OR "Nigerian government") min_faves:500'
}


def clean_text(text: str) -> str:
    """Normalize text and remove excessive whitespace."""
    if not text:
        return ""
    return re.sub(r"\s+", " ", text).strip()


def extract_tweet_id_from_url(url: str) -> str:
    """Extract numeric tweet ID from tweet status URL."""
    match = re.search(r"/status/(\d+)", url)
    return match.group(1) if match else ""


def scrape_category(page, base_url: str, category: str, query: str, max_items: int = 15) -> list:
    """Scrape viral tweets for a given category from a mirror instance."""
    encoded_query = quote_plus(query)
    search_url = f"{base_url}/search?f=tweets&q={encoded_query}"
    logger.info(f"[{category}] Fetching: {search_url}")

    results = []

    try:
        page.goto(search_url, wait_until="domcontentloaded", timeout=25000)
        # Wait briefly for timeline container
        try:
            page.wait_for_selector(".timeline-item, .timeline-none", timeout=8000)
        except PlaywrightTimeoutError:
            logger.warning(f"[{category}] Timeout waiting for timeline items.")
            return results

        tweet_elements = page.query_selector_all(".timeline-item")
        logger.info(f"[{category}] Found {len(tweet_elements)} raw timeline items.")

        for tweet_el in tweet_elements:
            if len(results) >= max_items:
                break

            # Skip pinned or unavailable placeholders
            if tweet_el.query_selector(".unavailable-box"):
                continue

            # Extract tweet link and ID
            link_el = tweet_el.query_selector(".tweet-link")
            if not link_el:
                continue

            href = link_el.get_attribute("href") or ""
            tweet_id = extract_tweet_id_from_url(href)
            if not tweet_id:
                continue

            # Extract Canonical X URL
            # href is typically /username/status/123456789#m
            status_path = re.sub(r"#.*$", "", href).lstrip("/")
            canonical_x_url = f"https://x.com/{status_path}"

            # Extract author
            author_el = tweet_el.query_selector(".fullname") or tweet_el.query_selector(".username")
            author = clean_text(author_el.inner_text()) if author_el else "Unknown"

            # Extract caption / content
            content_el = tweet_el.query_selector(".tweet-content")
            caption = clean_text(content_el.inner_text()) if content_el else ""

            # Extract media URL (image, gallery, video thumbnail/source)
            media_url = None
            
            # Check video attachment
            video_el = tweet_el.query_selector(".attachment.video-container video, video source")
            if video_el:
                media_url = video_el.get_attribute("src")
            
            # Check image attachment
            if not media_url:
                img_el = tweet_el.query_selector(".attachment.image img, .still-image img, .gallery-image img")
                if img_el:
                    media_url = img_el.get_attribute("src")

            # Resolve relative mirror media URLs
            if media_url and media_url.startswith("/"):
                media_url = f"{base_url}{media_url}"

            # Extract date if available
            date_el = tweet_el.query_selector(".tweet-date a")
            created_at = datetime.now(timezone.utc).isoformat()
            if date_el:
                date_title = date_el.get_attribute("title")
                if date_title:
                    try:
                        # Common Nitter format: "MMM d, yyyy · h:mm a UTC" e.g. "Aug 30, 2026 · 7:15 PM UTC"
                        parsed_dt = datetime.strptime(date_title.replace(" · ", " "), "%b %d, %Y %I:%M %p %Z")
                        created_at = parsed_dt.replace(tzinfo=timezone.utc).isoformat()
                    except Exception:
                        pass

            # Construct post payload (omit reaction counters so existing values are not overwritten)
            post_data = {
                "tweet_id": str(tweet_id),
                "author": author,
                "caption": caption,
                "media_url": media_url,
                "x_url": canonical_x_url,
                "category": category,
                "created_at": created_at
            }
            results.append(post_data)

    except Exception as err:
        logger.error(f"[{category}] Error during scraping on {base_url}: {err}")

    return results


def upsert_to_supabase(posts: list) -> int:
    """
    Upsert posts into the Supabase viral_tweets table.
    Preserves app_likes, app_dislikes, and app_comments_count on conflict.
    """
    if not posts:
        logger.info("No posts to upsert.")
        return 0

    try:
        # Deduplicate list by tweet_id before upsert
        unique_posts = list({p["tweet_id"]: p for p in posts}.values())
        
        # Upsert with on_conflict='tweet_id'
        response = supabase.table("viral_tweets").upsert(
            unique_posts,
            on_conflict="tweet_id"
        ).execute()

        logger.info(f"Successfully upserted {len(unique_posts)} posts into Supabase.")
        return len(unique_posts)
    except Exception as e:
        logger.error(f"Failed to upsert posts to Supabase: {e}")
        raise e


def run():
    """Main execution flow across all categories."""
    logger.info("Starting automated Playwright scraper for viral Nigerian tweets...")
    all_posts = []

    with sync_playwright() as p:
        # Launch Chromium headless with realistic desktop viewport and user-agent
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu"
            ]
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        for category, query in CATEGORIES.items():
            category_posts = []
            for mirror in MIRROR_INSTANCES:
                try:
                    category_posts = scrape_category(page, mirror, category, query)
                    if category_posts:
                        logger.info(f"[{category}] Scraped {len(category_posts)} posts from {mirror}")
                        break
                    else:
                        logger.warning(f"[{category}] Zero results from {mirror}. Trying fallback mirror...")
                except Exception as ex:
                    logger.warning(f"[{category}] Failed on {mirror}: {ex}. Trying next mirror...")

            all_posts.extend(category_posts)

        browser.close()

    logger.info(f"Total posts scraped across all categories: {len(all_posts)}")
    if all_posts:
        upsert_to_supabase(all_posts)


if __name__ == "__main__":
    run()
