import { createClient } from "jsr:@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...jsonHeaders, Allow: "POST" },
    });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return new Response(JSON.stringify({ error: "Authentication required" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !publishableKey || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Server configuration is incomplete" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const userClient = createClient(supabaseURL, publishableKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseURL, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData.user;
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Authentication required" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  try {
    const { data: memberships, error: membershipError } = await adminClient
      .from("club_memberships")
      .select("club_id, role, joined_at")
      .eq("user_id", user.id);
    if (membershipError) throw membershipError;

    const clubIDs = (memberships ?? []).map((membership) => membership.club_id as string);
    const orphanedClubIDs: string[] = [];

    for (const membership of memberships ?? []) {
      if (membership.role !== "owner") continue;

      const { data: successor, error: successorError } = await adminClient
        .from("club_memberships")
        .select("user_id")
        .eq("club_id", membership.club_id)
        .neq("user_id", user.id)
        .order("joined_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      if (successorError) throw successorError;

      if (successor) {
        const { error: transferError } = await adminClient
          .from("club_memberships")
          .update({ role: "owner" })
          .eq("club_id", membership.club_id)
          .eq("user_id", successor.user_id);
        if (transferError) throw transferError;
      } else {
        orphanedClubIDs.push(membership.club_id as string);
      }
    }

    const { data: profileFiles, error: profileListError } = await adminClient.storage
      .from("profile-photos")
      .list(user.id, { limit: 1000 });
    if (profileListError) throw profileListError;
    const profilePaths = (profileFiles ?? []).map((file) => `${user.id}/${file.name}`);
    if (profilePaths.length > 0) {
      const { error: profileRemoveError } = await adminClient.storage
        .from("profile-photos")
        .remove(profilePaths);
      if (profileRemoveError) throw profileRemoveError;
    }

    for (const clubID of clubIDs) {
      const prefix = `${clubID}/${user.id}`;
      const { data: ratingFiles, error: ratingListError } = await adminClient.storage
        .from("rating-photos")
        .list(prefix, { limit: 1000 });
      if (ratingListError) throw ratingListError;

      const ratingPaths = (ratingFiles ?? []).map((file) => `${prefix}/${file.name}`);
      if (ratingPaths.length > 0) {
        const { error: ratingRemoveError } = await adminClient.storage
          .from("rating-photos")
          .remove(ratingPaths);
        if (ratingRemoveError) throw ratingRemoveError;
      }
    }

    if (orphanedClubIDs.length > 0) {
      const { error: clubDeleteError } = await adminClient
        .from("clubs")
        .delete()
        .in("id", orphanedClubIDs);
      if (clubDeleteError) throw clubDeleteError;
    }

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ deleted: true }), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch (error) {
    console.error("Account deletion failed", error);
    return new Response(JSON.stringify({ error: "Account deletion failed" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
