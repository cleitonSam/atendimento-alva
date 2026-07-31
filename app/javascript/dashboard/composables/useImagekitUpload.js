// Upload client-side assinado pro ImageKit: pede a assinatura ao backend (authFn) e
// sobe o arquivo DIRETO pro ImageKit (fetch cru, sem mandar os headers de auth do app).
// A midia nao passa pelo nosso servidor. Serve pra imagem e video.
// authFn: () => Promise<{ data: { public_key, signature, expire, token, upload_url } }>
export function useImagekitUpload(authFn) {
  async function uploadToImagekit(file) {
    const { data: auth } = await authFn();
    if (!auth || auth.error)
      throw new Error(auth?.error || 'ImageKit auth failed');

    const fd = new FormData();
    fd.append('file', file);
    fd.append('fileName', file.name || 'upload');
    fd.append('publicKey', auth.public_key);
    fd.append('signature', auth.signature);
    fd.append('expire', auth.expire);
    fd.append('token', auth.token);
    fd.append('useUniqueFileName', 'true');

    const res = await fetch(auth.upload_url, { method: 'POST', body: fd });
    const json = await res.json().catch(() => ({}));
    if (!res.ok || !json.url)
      throw new Error(json?.message || 'ImageKit upload failed');
    return { url: json.url, fileId: json.fileId };
  }

  return { uploadToImagekit };
}
