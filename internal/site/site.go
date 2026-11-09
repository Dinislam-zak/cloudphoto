package site

import (
	"fmt"
	"html"
	"net/url"
	"strings"
)

func photoURL(album, filename string) string {
	u := url.URL{Path: "/album/" + album + "/" + filename}
	return u.EscapedPath()
}

func RenderError() []byte {
	return []byte(`<!doctype html>
<html>
    <head>
        <title>Фотоархив</title>
    </head>
<body>
    <h1>Ошибка</h1>
    <p>Ошибка при доступе к фотоархиву. Вернитесь на <a href="index.html">главную страницу</a> фотоархива.</p>
</body>
`)
}

func RenderIndex(albums []string) []byte {
	if len(albums) == 0 {
		return []byte(`<!doctype html>
<html>
    <head>
        <title>Фотоархив</title>
    </head>
<body>
    <h1>Фотоархив</h1>
    <p>Фотоархив пустой.</p>
</body>
`)
	}
	var b strings.Builder
	b.WriteString(`<!doctype html>
<html>
    <head>
        <title>Фотоархив</title>
    </head>
<body>
    <h1>Фотоархив</h1>
    <ul><!--1-->
`)
	for i, album := range albums {
		b.WriteString(fmt.Sprintf("        <li><a href=\"album%d.html\">%s</a></li>\n", i+1, html.EscapeString(album)))
	}
	b.WriteString(`    </ul>
</body>
`)
	return []byte(b.String())
}

func RenderAlbum(album string, photos []string) []byte {
	esc := html.EscapeString(album)
	if len(photos) == 0 {
		return []byte(fmt.Sprintf(`<!doctype html>
<html>
    <head>
        <title>Фотоальбом "%s"</title>
    </head>
    <body>
        <h1>Фотоальбом "%s"</h1>
        <p>Фотоальбом пустой.</p>
        <p>Вернуться на <a href="index.html">главную страницу</a> фотоархива</p>
    </body>
</html>
`, esc, esc))
	}
	var b strings.Builder
	b.WriteString(fmt.Sprintf(`<!doctype html>
<html>
    <head>
        <title>Фотоальбом "%s"</title>
        <link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/galleria/1.6.1/themes/classic/galleria.classic.min.css" />
        <style>
            .galleria{ width: 960px; height: 540px; background: #000 }
        </style>
        <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/galleria/1.6.1/galleria.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/galleria/1.6.1/themes/classic/galleria.classic.min.js"></script>
    </head>
    <body>
        <h1>Фотоальбом "%s"</h1>
        <div class="galleria">
`, esc, esc))
	for _, photo := range photos {
		b.WriteString(fmt.Sprintf("            <img src=\"%s\" data-title=\"%s\">\n", photoURL(album, photo), html.EscapeString(photo)))
	}
	b.WriteString(`        </div>
        <p>Вернуться на <a href="index.html">главную страницу</a> фотоархива</p>
        <script>
            (function() {
                Galleria.run('.galleria');
            }());
        </script>
    </body>
</html>
`)
	return []byte(b.String())
}
