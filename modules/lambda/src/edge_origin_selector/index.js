'use strict';

exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;

  try {
    const headerValue = request.origin?.custom?.customHeaders?.['x-origin-list']?.[0]?.value;
    if (!headerValue) throw new Error("Missing x-origin-list header.");

    const origins = headerValue.split(',').map(o => o.trim()).filter(Boolean);
    if (origins.length === 0) throw new Error("No valid origins in x-origin-list.");


    const xff = request.headers['x-forwarded-for']?.[0]?.value || '0.0.0.0';
    const clientIp = xff.split(',')[0].trim();

    const hash = [...clientIp].reduce((acc, char) => acc + char.charCodeAt(0), 0);
    const chosenOrigin = origins[hash % origins.length];

    console.log(`Chosen Origin: ${chosenOrigin} for IP: ${clientIp}`);

    request.origin.custom.domainName = chosenOrigin;
    callback(null, request);
  } catch (err) {
    console.log("Lambda@Edge Error:", err.message);
    callback(null, request);  
  }
};
