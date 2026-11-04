using System.Collections.Generic;
using UnityEngine;

/// Plays the Free Game & UI Sound Pack sounds by name.
/// Put the ogg (or wav) folders under Assets/Resources/GameSfx, add this
/// component to one GameObject and call GameSfx.Play("jump") from anywhere.
public class GameSfx : MonoBehaviour
{
    public static GameSfx Instance { get; private set; }

    [Tooltip("Leave empty to load every clip from Resources/GameSfx.")]
    public AudioClip[] clips;
    public string resourcesFolder = "GameSfx";
    [Range(1, 32)] public int voices = 8;
    [Range(0f, 1f)] public float volume = 1f;

    readonly Dictionary<string, AudioClip> byName = new Dictionary<string, AudioClip>();
    AudioSource[] sources;
    int next;

    void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
        if (clips == null || clips.Length == 0)
            clips = Resources.LoadAll<AudioClip>(resourcesFolder);
        foreach (var c in clips)
            if (c != null && !byName.ContainsKey(c.name))
                byName.Add(c.name, c);
        sources = new AudioSource[voices];
        for (int i = 0; i < voices; i++)
        {
            sources[i] = gameObject.AddComponent<AudioSource>();
            sources[i].playOnAwake = false;
        }
    }

    public static AudioSource Play(string soundName, float pitchVariation = 0f, float volumeScale = 1f)
    {
        if (Instance == null)
        {
            Debug.LogWarning("GameSfx: add the GameSfx component to a GameObject first.");
            return null;
        }
        return Instance.PlayClip(soundName, pitchVariation, volumeScale);
    }

    public AudioSource PlayClip(string soundName, float pitchVariation, float volumeScale)
    {
        AudioClip clip;
        if (!byName.TryGetValue(soundName, out clip))
        {
            Debug.LogWarning("GameSfx: unknown sound " + soundName);
            return null;
        }
        var s = sources[next];
        next = (next + 1) % sources.Length;
        s.clip = clip;
        s.volume = volume * volumeScale;
        s.pitch = 1f + Random.Range(-pitchVariation, pitchVariation);
        s.Play();
        return s;
    }

    public IEnumerable<string> Names()
    {
        return byName.Keys;
    }
}
