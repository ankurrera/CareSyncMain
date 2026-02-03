// Supabase Edge Function for Azure Face API Integration
// Deploy with: supabase functions deploy azure-face

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Validate Environment Variables
    const azureApiKey = Deno.env.get("AZURE_FACE_API_KEY");
    const azureEndpointRaw = Deno.env.get("AZURE_FACE_API_ENDPOINT");
    const personGroupId = Deno.env.get("AZURE_FACE_PERSON_GROUP_ID") || "caresync-patients";
    
    if (!azureApiKey || !azureEndpointRaw) {
      console.error("[AZURE-FACE] Missing Azure credentials in environment.");
      return new Response(
        JSON.stringify({ error: "Azure Face API is not configured on the server." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const azureEndpoint = azureEndpointRaw.replace(/\/$/, ""); // Strip trailing slash

    // 2. Initialize Supabase Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 3. Parse Request Body
    const body = await req.json();
    const { action } = body;

    // 4. Ensure Azure Person Group Exists
    await ensurePersonGroupExists(azureEndpoint, azureApiKey, personGroupId);

    // 5. Route Actions
    if (action === "enroll") {
      const { userId, selfieUrl } = body;
      if (!userId || !selfieUrl) {
        return new Response(
          JSON.stringify({ error: "Missing userId or selfieUrl parameter." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      return await handleEnroll(supabase, azureEndpoint, azureApiKey, personGroupId, userId, selfieUrl);
    } 
    
    else if (action === "identify") {
      const { scanPath } = body;
      if (!scanPath) {
        return new Response(
          JSON.stringify({ error: "Missing scanPath parameter." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      return await handleIdentify(supabase, azureEndpoint, azureApiKey, personGroupId, scanPath);
    } 
    
    else {
      return new Response(
        JSON.stringify({ error: `Unsupported action: ${action}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

  } catch (err: any) {
    console.error("[AZURE-FACE] General error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "An unexpected error occurred." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

/**
 * Ensures that the Azure Person Group exists. If not, creates it.
 */
async function ensurePersonGroupExists(endpoint: string, apiKey: string, groupId: string) {
  const url = `${endpoint}/face/v1.0/persongroups/${groupId}`;
  
  // Check if exists
  const getResponse = await fetch(url, {
    method: "GET",
    headers: { "Ocp-Apim-Subscription-Key": apiKey }
  });

  if (getResponse.status === 200) {
    return; // Group already exists
  }

  if (getResponse.status === 404) {
    console.log(`[AZURE-FACE] Person group "${groupId}" not found. Creating a new group...`);
    
    const putResponse = await fetch(url, {
      method: "PUT",
      headers: {
        "Ocp-Apim-Subscription-Key": apiKey,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        name: "CareSync Patients Group",
        recognitionModel: "recognition_04"
      })
    });

    if (!putResponse.ok) {
      const errorText = await putResponse.text();
      throw new Error(`Failed to create Azure Person Group: ${errorText}`);
    }
    
    console.log(`[AZURE-FACE] Successfully created Person Group "${groupId}".`);
  } else {
    const errorText = await getResponse.text();
    throw new Error(`Failed to verify Azure Person Group: ${errorText}`);
  }
}

/**
 * Enrolls a patient face into Azure Face API.
 */
async function handleEnroll(
  supabase: any,
  endpoint: string,
  apiKey: string,
  groupId: string,
  userId: string,
  selfieUrl: string
) {
  try {
    // 1. Verify patient exists in database
    const { data: patient, error: patientErr } = await supabase
      .from("patients")
      .select("id, azure_person_id")
      .eq("user_id", userId)
      .maybeSingle();

    if (patientErr || !patient) {
      return new Response(
        JSON.stringify({ error: "Patient profile not found in database. Complete registration first." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let personId = patient.azure_person_id;

    // 2. Create Azure Person if not already created
    if (!personId) {
      console.log(`[AZURE-FACE] Creating new Azure Person for user: ${userId}`);
      const createPersonUrl = `${endpoint}/face/v1.0/persongroups/${groupId}/persons`;
      
      const createResponse = await fetch(createPersonUrl, {
        method: "POST",
        headers: {
          "Ocp-Apim-Subscription-Key": apiKey,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ name: userId })
      });

      if (!createResponse.ok) {
        const errText = await createResponse.text();
        throw new Error(`Failed to create Azure Person: ${errText}`);
      }

      const createData = await createResponse.json();
      personId = createData.personId;
    }

    // 3. Add Selfie Face to the Azure Person
    console.log(`[AZURE-FACE] Adding face to Azure Person: ${personId}`);
    const addFaceUrl = `${endpoint}/face/v1.0/persongroups/${groupId}/persons/${personId}/persistedFaces?detectionModel=detection_03`;
    
    const faceResponse = await fetch(addFaceUrl, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": apiKey,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ url: selfieUrl })
    });

    if (!faceResponse.ok) {
      const errText = await faceResponse.text();
      throw new Error(`Failed to add face image to Azure Person: ${errText}`);
    }

    const faceData = await faceResponse.json();
    const persistedFaceId = faceData.persistedFaceId;

    // 4. Trigger Person Group Training (asynchronous but we invoke it)
    console.log(`[AZURE-FACE] Triggering training for Person Group: ${groupId}`);
    const trainUrl = `${endpoint}/face/v1.0/persongroups/${groupId}/train`;
    const trainResponse = await fetch(trainUrl, {
      method: "POST",
      headers: { "Ocp-Apim-Subscription-Key": apiKey }
    });

    if (!trainResponse.ok) {
      const errText = await trainResponse.text();
      console.warn(`[AZURE-FACE] Warning: Failed to trigger training: ${errText}`);
    }

    // 5. Update Database Record
    const { error: updateErr } = await supabase
      .from("patients")
      .update({
        azure_person_id: personId,
        azure_persisted_face_id: persistedFaceId,
        updated_at: new Date().toISOString()
      })
      .eq("user_id", userId);

    if (updateErr) {
      throw new Error(`Failed to update patient record with Azure references: ${updateErr.message}`);
    }

    return new Response(
      JSON.stringify({ success: true, personId, persistedFaceId }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: any) {
    console.error("[AZURE-FACE] Enrollment failed:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Face enrollment failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}

/**
 * Identifies a patient from a scanned face photo.
 */
async function handleIdentify(
  supabase: any,
  endpoint: string,
  apiKey: string,
  groupId: string,
  scanPath: string
) {
  try {
    // 1. Download image bytes from Supabase Storage
    console.log(`[AZURE-FACE] Downloading scan file: ${scanPath}`);
    const { data: fileData, error: downloadErr } = await supabase.storage
      .from("emergency-scans")
      .download(scanPath);

    if (downloadErr || !fileData) {
      throw new Error(`Failed to download scan file from storage: ${downloadErr?.message || "File empty"}`);
    }

    // Convert Blob to ArrayBuffer
    const imageBytes = await fileData.arrayBuffer();

    // 2. Detect face in the image to get a temporary faceId
    console.log("[AZURE-FACE] Detecting face in scanned image...");
    const detectUrl = `${endpoint}/face/v1.0/detect?returnFaceId=true&recognitionModel=recognition_04&detectionModel=detection_03`;
    
    const detectResponse = await fetch(detectUrl, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": apiKey,
        "Content-Type": "application/octet-stream"
      },
      body: imageBytes
    });

    if (!detectResponse.ok) {
      const errText = await detectResponse.text();
      throw new Error(`Azure Face Detection failed: ${errText}`);
    }

    const detectedFaces = await detectResponse.json();
    if (!detectedFaces || detectedFaces.length === 0) {
      return new Response(
        JSON.stringify({ error: "No face detected in the image. Please verify lighting and camera alignment." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const faceId = detectedFaces[0].faceId;
    console.log(`[AZURE-FACE] Detected faceId: ${faceId}. Proceeding to identify...`);

    // 3. Identify faceId against the Person Group
    const identifyUrl = `${endpoint}/face/v1.0/identify`;
    const identifyResponse = await fetch(identifyUrl, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": apiKey,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        personGroupId: groupId,
        faceIds: [faceId],
        maxNumOfCandidatesReturned: 1,
        confidenceThreshold: 0.65 // Minimum confidence of 65% match
      })
    });

    if (!identifyResponse.ok) {
      const errText = await identifyResponse.text();
      throw new Error(`Azure Face Identification failed: ${errText}`);
    }

    const identifyResults = await identifyResponse.json();
    if (!identifyResults || identifyResults.length === 0 || identifyResults[0].candidates.length === 0) {
      return new Response(
        JSON.stringify({ error: "No matching patient profile found in database." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const topCandidate = identifyResults[0].candidates[0];
    const matchedPersonId = topCandidate.personId;
    const confidence = topCandidate.confidence;
    console.log(`[AZURE-FACE] Matched PersonId: ${matchedPersonId} with confidence: ${confidence}`);

    // 4. Query database for patient using Azure Person ID
    const { data: patient, error: dbErr } = await supabase
      .from("patients")
      .select("id, qr_code_id, profiles!inner(full_name)")
      .eq("azure_person_id", matchedPersonId)
      .maybeSingle();

    if (dbErr || !patient) {
      return new Response(
        JSON.stringify({ error: "Face matches Azure ID but no patient record exists in database." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        patient_id: patient.id,
        qr_code_id: patient.qr_code_id,
        full_name: patient.profiles.full_name,
        similarity: confidence
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: any) {
    console.error("[AZURE-FACE] Identification flow failed:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Face matching process failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}
