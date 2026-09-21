# Strip the intentional v7.435 Search-only floor delta before historical shared-floor hashes.
def strip_search7435(s: str) -> str:
    start='\n        // v7.435 VIEWPORT r1/r2: exact sponsored result + Shop-by-brand owners.\n'
    end='        // v7.174 probe r4: exact Explore key features renderer.\n'
    i=s.find(start)
    if i < 0:
        return s
    j=s.find(end, i)
    if j < 0:
        raise AssertionError('v7.435 Search delta end marker missing')
    return s[:i] + '\n' + s[j:]
