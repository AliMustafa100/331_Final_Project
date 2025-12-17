package edu.qc.project3;

import java.awt.BorderLayout;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.Vector;

import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.JTextArea;
import javax.swing.SwingUtilities;
import javax.swing.WindowConstants;
import javax.swing.table.DefaultTableModel;

public class Project3 {

    // ============================
    // CONFIG (FINAL)
    // ============================
    private static final String SERVER   = "localhost";
    private static final int    PORT     = 1433;
    private static final String DATABASE = "QueensClassSchedule";
    private static final String USER     = "sa";
    private static final String PASSWORD = "Adi123!Ab";

    // Your existing authorization key
    private static final int USER_AUTH_KEY = 3;

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            JFrame frame = new JFrame("Project 3 - JDBC Workflow Demo");
            frame.setDefaultCloseOperation(WindowConstants.EXIT_ON_CLOSE);
            frame.setSize(1100, 500);
            frame.setLocationRelativeTo(null);

            JTextArea log = new JTextArea(6, 80);
            log.setEditable(false);
            JScrollPane logScroll = new JScrollPane(log);

            JTable table = new JTable();
            JScrollPane tableScroll = new JScrollPane(table);

            JButton runBtn = new JButton("Run Master ETL + Show Workflow Steps");
            runBtn.addActionListener(e -> {
                runBtn.setEnabled(false);
                log.setText("");

                new Thread(() -> {
                    try (Connection conn = getConnection()) {
                        conn.setAutoCommit(true);

                        logAppend(log, "Connected ✅");

                        // 1) Run Master ETL
                        logAppend(log, "Running Project3.LoadQueensCourseSchedule...");
                        callMasterETL(conn, USER_AUTH_KEY);
                        logAppend(log, "Master ETL finished ✅");

                        // 2) Show workflow steps
                        logAppend(log, "Fetching Process.usp_ShowWorkflowSteps...");
                        DefaultTableModel model = fetchWorkflowSteps(conn, USER_AUTH_KEY);
                        SwingUtilities.invokeLater(() -> table.setModel(model));
                        logAppend(log, "Workflow loaded into JTable ✅");

                    } catch (SQLException ex) {
                        logAppend(log, "SQL ERROR ❌: " + ex.getMessage());
                    } catch (Exception ex) {
                        logAppend(log, "ERROR ❌: " + ex.getMessage());
                    } finally {
                        SwingUtilities.invokeLater(() -> runBtn.setEnabled(true));
                    }
                }).start();
            });

            JPanel top = new JPanel(new BorderLayout());
            top.add(runBtn, BorderLayout.WEST);

            frame.setLayout(new BorderLayout(10, 10));
            frame.add(top, BorderLayout.NORTH);
            frame.add(tableScroll, BorderLayout.CENTER);
            frame.add(logScroll, BorderLayout.SOUTH);

            frame.setVisible(true);
        });
    }

    // ============================
    // CONNECTION (FINAL)
    // ============================
    private static Connection getConnection() throws SQLException {
        String url =
                "jdbc:sqlserver://" + SERVER + ":" + PORT + ";"
                        + "databaseName=" + DATABASE + ";"
                        + "encrypt=true;"
                        + "trustServerCertificate=true;"
                        + "loginTimeout=10;";

        System.out.println("JDBC URL = " + url);
        return DriverManager.getConnection(url, USER, PASSWORD);
    }

    // ============================
    // STORED PROC CALLS
    // ============================
    private static void callMasterETL(Connection conn, int userAuthorizationKey) throws SQLException {
        // Stored proc signature: Project3.LoadQueensCourseSchedule(@UserAuthorizationKey INT)
        String sql = "{call Project3.LoadQueensCourseSchedule(?)}";
        try (CallableStatement cs = conn.prepareCall(sql)) {
            cs.setInt(1, userAuthorizationKey);
            cs.execute();
        }
    }

    private static DefaultTableModel fetchWorkflowSteps(Connection conn, int userAuthorizationKey) throws SQLException {
        // Stored proc signature: Process.usp_ShowWorkflowSteps(@UserAuthorizationKey INT = NULL)
        String sql = "{call Process.usp_ShowWorkflowSteps(?)}";
        try (CallableStatement cs = conn.prepareCall(sql)) {
            cs.setInt(1, userAuthorizationKey);
            try (ResultSet rs = cs.executeQuery()) {
                return buildTableModel(rs);
            }
        }
    }

    // ============================
    // RESULTSET -> JTable MODEL
    // ============================
    private static DefaultTableModel buildTableModel(ResultSet rs) throws SQLException {
        ResultSetMetaData meta = rs.getMetaData();
        int colCount = meta.getColumnCount();

        Vector<String> columns = new Vector<>();
        for (int i = 1; i <= colCount; i++) {
            columns.add(meta.getColumnLabel(i));
        }

        Vector<Vector<Object>> data = new Vector<>();
        while (rs.next()) {
            Vector<Object> row = new Vector<>();
            for (int i = 1; i <= colCount; i++) {
                row.add(rs.getObject(i));
            }
            data.add(row);
        }

        return new DefaultTableModel(data, columns) {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };
    }

    private static void logAppend(JTextArea log, String msg) {
        SwingUtilities.invokeLater(() -> log.append(msg + "\n"));
    }
}
