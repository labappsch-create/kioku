import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

/** Genera los íconos cuadrados a partir de assets/icono/original.jpg.
 *  Uso: java herramientas/Iconos.java */
public class Iconos {
  public static void main(String[] a) throws Exception {
    BufferedImage src = ImageIO.read(new File("assets/icono/original.jpg"));
    int minX = src.getWidth(), minY = src.getHeight(), maxX = -1, maxY = -1;
    for (int y = 0; y < src.getHeight(); y++)
      for (int x = 0; x < src.getWidth(); x++) {
        int p = src.getRGB(x, y);
        int r = (p >> 16) & 255, g = (p >> 8) & 255, b = p & 255;
        if (Math.max(r, Math.max(g, b)) > 70) {
          minX = Math.min(minX, x); maxX = Math.max(maxX, x);
          minY = Math.min(minY, y); maxY = Math.max(maxY, y);
        }
      }
    int w = maxX - minX + 1, h = maxY - minY + 1;
    System.out.printf("Dibujo encontrado: x=%d y=%d %dx%d%n", minX, minY, w, h);
    BufferedImage dibujo = src.getSubimage(minX, minY, w, h);
    guardar(dibujo, 1024, 0.80, "assets/icono/icono.png");
    guardar(dibujo, 1024, 0.58, "assets/icono/icono_frente.png");
    guardar(dibujo, 768, 0.80, "assets/icono/splash.png");
    guardar(dibujo, 1152, 0.62, "assets/icono/splash_12.png");
  }

  /** Lienzo cuadrado negro con el dibujo centrado ocupando [fraccion]. */
  static void guardar(BufferedImage dibujo, int lado, double fraccion, String ruta) throws Exception {
    BufferedImage out = new BufferedImage(lado, lado, BufferedImage.TYPE_INT_RGB);
    Graphics2D g = out.createGraphics();
    g.setColor(Color.BLACK);
    g.fillRect(0, 0, lado, lado);
    g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
    g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
    double escala = lado * fraccion / Math.max(dibujo.getWidth(), dibujo.getHeight());
    int dw = (int) Math.round(dibujo.getWidth() * escala), dh = (int) Math.round(dibujo.getHeight() * escala);
    g.drawImage(dibujo, (lado - dw) / 2, (lado - dh) / 2, dw, dh, null);
    g.dispose();
    ImageIO.write(out, "png", new File(ruta));
    System.out.printf("%s: %dx%d, dibujo %dx%d%n", ruta, lado, lado, dw, dh);
  }
}
