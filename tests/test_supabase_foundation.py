"""Static security-contract checks for the Phase 13B-1 Supabase migration."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260921000000_cms_foundation.sql"
GRANTS_MIGRATION = ROOT / "supabase/migrations/20260921000001_cms_authenticated_grants.sql"
NEWS_MIGRATION = ROOT / "supabase/migrations/20260921000002_cms_news_drafts.sql"


class SupabaseFoundationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = MIGRATION.read_text(encoding="utf-8")
        cls.grants_sql = GRANTS_MIGRATION.read_text(encoding="utf-8")
        cls.news_sql = NEWS_MIGRATION.read_text(encoding="utf-8")

    def test_profiles_are_constrained_and_rls_protected(self):
        self.assertRegex(self.sql, r"create table public\.profiles")
        self.assertIn("references auth.users(id) on delete cascade", self.sql)
        self.assertIn("check (role in ('admin', 'editor', 'contributor'))", self.sql)
        self.assertIn("check (status in ('active', 'suspended'))", self.sql)
        self.assertIn("alter table public.profiles enable row level security", self.sql)
        self.assertIn("role text not null default 'contributor'", self.sql)

    def test_profiles_cannot_be_self_promoted(self):
        self.assertIn("create policy \"cms admins update profiles\"", self.sql)
        self.assertNotRegex(self.sql, r"on public\.profiles for update to authenticated\s+using \(id =")
        self.assertIn("revoke all on function public.cms_is_admin() from public", self.sql)
        self.assertIn("set search_path = ''", self.sql)

    def test_audit_events_are_append_only_for_clients(self):
        self.assertIn("create table public.audit_events", self.sql)
        self.assertIn("alter table public.audit_events enable row level security", self.sql)
        self.assertIn("-- INSERT policy exists in this foundation migration.", self.sql)
        self.assertNotRegex(self.sql, r"on public\.audit_events for (insert|update|delete) to authenticated")
        self.assertIn("create policy \"cms users read own audit events\"", self.sql)
        self.assertIn("create policy \"cms editors read editorial audit events\"", self.sql)
        self.assertIn("create policy \"cms admins read all audit events\"", self.sql)

    def test_authenticated_table_grants_remain_minimal_and_rls_protected(self):
        self.assertIn("grant select, update on public.profiles to authenticated;", self.grants_sql)
        self.assertIn("grant select on public.audit_events to authenticated;", self.grants_sql)
        self.assertIn("revoke insert, delete on public.profiles from authenticated;", self.grants_sql)
        self.assertIn("revoke insert, update, delete on public.audit_events from authenticated;", self.grants_sql)
        self.assertNotIn("grant all", self.grants_sql.lower())
        self.assertNotIn("disable row level security", self.grants_sql.lower())

    def test_news_draft_schema_workflow_and_database_validation(self):
        sql = self.news_sql
        self.assertIn("create table public.cms_news", sql)
        self.assertIn("alter table public.cms_news enable row level security", sql)
        for content_type in ("'news'", "'event'", "'award'", "'project'", "'open-source'", "'team'", "'collaboration'", "'demo'"):
            self.assertIn(content_type, sql)
        self.assertIn("check (type <> 'event' or event_date is not null)", sql)
        self.assertIn("check (end_date is null or event_date is null or end_date >= event_date)", sql)
        self.assertIn("between 1 and 180", sql)
        self.assertIn("between 1 and 600", sql)
        self.assertIn("between 1 and 30000", sql)
        self.assertIn("body not like '%{{%'", sql)
        self.assertIn("body not like '%{%'", sql)
        self.assertIn("title not like '%{{%'", sql)
        self.assertIn("summary not like '%{{%'", sql)
        self.assertIn("'<[[:space:]]*script", sql)
        self.assertIn("status in ('draft', 'in_review')", sql)

    def test_news_draft_rls_grants_and_audit_are_limited(self):
        sql = self.news_sql
        self.assertIn("cms users create own news drafts", sql)
        self.assertIn("cms users update own news drafts", sql)
        self.assertIn("cms editorial users read all news drafts", sql)
        self.assertIn("cms editorial users update all news drafts", sql)
        self.assertIn("grant select on public.cms_news to authenticated;", sql)
        self.assertIn("grant insert (title, type, summary, body", sql)
        self.assertIn("grant update (title, type, summary, body", sql)
        self.assertNotIn("grant delete", sql.lower())
        self.assertIn("created_by = (select auth.uid()) and status = 'draft'", sql)
        self.assertIn("public.cms_is_editor_or_admin()", sql)
        self.assertIn("with check (public.cms_is_editor_or_admin() and status in ('draft', 'in_review'))", sql)
        self.assertNotIn("status in ('draft', 'in_review',", sql)
        self.assertNotIn("grant insert (id", sql.lower())
        self.assertNotIn("created_by) on public.cms_news", sql)
        self.assertIn("event_name = 'news_created'", sql)
        self.assertIn("event_name = 'news_updated'", sql)
        self.assertIn("event_name = 'news_submitted_for_review'", sql)
        self.assertNotRegex(sql, r"on public\.audit_events for insert to authenticated")

    def test_private_media_bucket_and_policies_are_restricted(self):
        self.assertIn("'cms-media-private'", self.sql)
        self.assertIn("false,\n  10485760", self.sql)
        for mime_type in ("image/jpeg", "image/png", "image/webp"):
            self.assertIn(mime_type, self.sql)
        self.assertIn("cms users upload to own private media namespace", self.sql)
        self.assertIn("cms editorial users read private media", self.sql)
        self.assertNotIn("cms users delete private media namespace", self.sql)

    def test_no_real_secret_values_are_introduced(self):
        environment = (ROOT / ".env.example").read_text(encoding="utf-8")
        self.assertRegex(environment, r"(?m)^SUPABASE_URL=$")
        self.assertRegex(environment, r"(?m)^SUPABASE_PUBLISHABLE_KEY=$")
        self.assertNotRegex(environment, r"(?i)(service[_-]?role|sb_secret|ghp_)[^\n=]*=")
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn(".env", gitignore)
        self.assertIn("!.env.example", gitignore)

    def test_migration_has_balanced_dollar_quoting(self):
        self.assertEqual(self.sql.count("$$"), 10)
        policy_statements = re.findall(r"\bcreate policy\b.*?;", self.sql, re.IGNORECASE | re.DOTALL)
        self.assertEqual(self.sql.lower().count("create policy"), len(policy_statements))


if __name__ == "__main__":
    unittest.main()
